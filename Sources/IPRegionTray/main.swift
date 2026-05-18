import AppKit
import CryptoKit
import Foundation
import Network
import OSLog
import SystemConfiguration

struct IPInfoResponse: Decodable {
    let ip: String?
    let city: String?
    let region: String?
    let country: String?
    let org: String?
    let timezone: String?
}

struct AppConfig {
    static let defaultURL = "https://ipinfo.io/json"
    static let defaultMinimumRefreshInterval: TimeInterval = 60
    static let minimumAllowedRefreshInterval: TimeInterval = 15
    static let urlKey = "sourceURL"
    static let minimumRefreshIntervalKey = "minimumRefreshInterval"
    static let legacyRefreshIntervalKey = "refreshInterval"

    var sourceURL: URL
    var minimumRefreshInterval: TimeInterval

    static func load() -> AppConfig {
        let defaults = UserDefaults.standard
        let urlString = defaults.string(forKey: urlKey) ?? defaultURL
        let sourceURL = URL(string: urlString) ?? URL(string: defaultURL)!
        let savedMinimumInterval = defaults.double(forKey: minimumRefreshIntervalKey)
        let legacyInterval = defaults.double(forKey: legacyRefreshIntervalKey)
        let interval: TimeInterval
        if savedMinimumInterval > 0 {
            interval = savedMinimumInterval
        } else if legacyInterval > 0 {
            interval = max(defaultMinimumRefreshInterval, legacyInterval)
        } else {
            interval = defaultMinimumRefreshInterval
        }

        return AppConfig(
            sourceURL: sourceURL,
            minimumRefreshInterval: max(minimumAllowedRefreshInterval, interval)
        )
    }

    func save() {
        UserDefaults.standard.set(sourceURL.absoluteString, forKey: Self.urlKey)
        UserDefaults.standard.set(minimumRefreshInterval, forKey: Self.minimumRefreshIntervalKey)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.rjblue.IPRegionTray", category: "network")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "ip-region-tray.network-monitor")
    private var dynamicStore: SCDynamicStore?
    private var dynamicStoreRunLoopSource: CFRunLoopSource?
    private var debounceWorkItem: DispatchWorkItem?
    private var scheduledRefreshWorkItem: DispatchWorkItem?
    private var settingsWindowController: SettingsWindowController?
    private var config = AppConfig.load()
    private var currentInfo: IPInfoResponse?
    private var lastError: String?
    private var lastUpdatedAt: Date?
    private var lastExternalRequestAt: Date?
    private var lastObservedEventAt: Date?
    private var lastObservedReason: String?
    private var latestNetworkFingerprint: String?
    private var backoffUntil: Date?
    private var backoffStep = 0
    private var fetchTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        startNetworkMonitor()
        startSystemConfigurationMonitor()
        startWorkspaceMonitor()
        handleNetworkSignal(reason: "Startup", forceFingerprintChange: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        debounceWorkItem?.cancel()
        scheduledRefreshWorkItem?.cancel()
        monitor.cancel()
        stopSystemConfigurationMonitor()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        fetchTask?.cancel()
    }

    private func configureStatusItem() {
        statusItem.length = 54
        statusItem.button?.title = "--"
        statusItem.button?.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        statusItem.button?.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "IP Region")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.imagePosition = .imageLeading
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if let currentInfo {
            menu.addItem(disabledItem("Country: \(currentInfo.country ?? "--")"))
            menu.addItem(disabledItem("IP: \(currentInfo.ip ?? "--")"))
            menu.addItem(disabledItem("Region: \(currentInfo.region ?? "--")"))
            if let city = currentInfo.city, !city.isEmpty {
                menu.addItem(disabledItem("City: \(city)"))
            }
            if let org = currentInfo.org, !org.isEmpty {
                menu.addItem(disabledItem("Org: \(org)"))
            }
        } else {
            menu.addItem(disabledItem("Country: --"))
            if let lastError {
                menu.addItem(disabledItem("Error: \(lastError)"))
            } else {
                menu.addItem(disabledItem("Waiting for first refresh..."))
            }
        }

        menu.addItem(.separator())
        menu.addItem(disabledItem("Source: \(config.sourceURL.absoluteString)"))
        menu.addItem(disabledItem("Refresh: event-driven"))
        menu.addItem(disabledItem("Minimum interval: \(formatInterval(config.minimumRefreshInterval))"))
        if let lastUpdatedAt {
            menu.addItem(disabledItem("Last updated: \(formatDate(lastUpdatedAt))"))
        }
        if let lastObservedReason {
            menu.addItem(disabledItem("Last signal: \(lastObservedReason)"))
        }
        if let backoffUntil, backoffUntil > Date() {
            menu.addItem(disabledItem("Backoff until: \(formatDate(backoffUntil))"))
        } else if let nextAllowedRefreshDate, nextAllowedRefreshDate > Date() {
            menu.addItem(disabledItem("Next allowed: \(formatDate(nextAllowedRefreshDate))"))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNowFromMenu), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit IP Region Tray", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }

        statusItem.menu = menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let rounded = interval.rounded()
        if rounded == interval {
            return "\(Int(rounded))s"
        }
        return String(format: "%.1fs", interval)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in
                self?.handleNetworkSignal(reason: "Network path changed")
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func startSystemConfigurationMonitor() {
        let callback: SCDynamicStoreCallBack = { _, changedKeys, info in
            guard let info else { return }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
            let keys = (changedKeys as? [String]) ?? []
            Task { @MainActor in
                appDelegate.handleNetworkSignal(reason: appDelegate.describeSystemConfigurationChange(keys))
            }
        }

        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let store = SCDynamicStoreCreate(nil, "IPRegionTray" as CFString, callback, &context) else {
            logger.error("Failed to create SystemConfiguration dynamic store")
            return
        }

        let keys = [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6",
            "State:/Network/Global/DNS",
            "State:/Network/Global/Proxies",
            "Setup:/Network/Global/Proxies"
        ] as CFArray

        let patterns = [
            "State:/Network/Service/.*/IPv4",
            "State:/Network/Service/.*/IPv6",
            "State:/Network/Service/.*/DNS",
            "State:/Network/Service/.*/Proxies",
            "State:/Network/Interface/.*/IPv4",
            "State:/Network/Interface/.*/IPv6",
            "State:/Network/Interface/.*/Link",
            "Setup:/Network/Service/.*/Proxies"
        ] as CFArray

        guard SCDynamicStoreSetNotificationKeys(store, keys, patterns),
              let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) else {
            logger.error("Failed to register SystemConfiguration notifications")
            return
        }

        dynamicStore = store
        dynamicStoreRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func stopSystemConfigurationMonitor() {
        if let dynamicStoreRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), dynamicStoreRunLoopSource, .commonModes)
        }
        dynamicStoreRunLoopSource = nil
        dynamicStore = nil
    }

    private func startWorkspaceMonitor() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func systemDidWake() {
        handleNetworkSignal(reason: "System woke")
    }

    private func describeSystemConfigurationChange(_ keys: [String]) -> String {
        if keys.contains(where: { $0.contains("Proxies") }) {
            return "Proxy settings changed"
        }
        if keys.contains(where: { $0.contains("/DNS") }) {
            return "DNS settings changed"
        }
        if keys.contains(where: { $0.contains("/Interface/") || $0.contains("/IPv4") || $0.contains("/IPv6") }) {
            return "Network interface changed"
        }
        return "System network settings changed"
    }

    @objc private func refreshNowFromMenu() {
        handleNetworkSignal(reason: "Manual refresh", forceFingerprintChange: true, forceRequest: true)
    }

    private func handleNetworkSignal(
        reason: String,
        forceFingerprintChange: Bool = false,
        forceRequest: Bool = false
    ) {
        let fingerprint = NetworkFingerprint.current()
        let fingerprintChanged = forceFingerprintChange || fingerprint != latestNetworkFingerprint
        latestNetworkFingerprint = fingerprint
        lastObservedEventAt = Date()
        lastObservedReason = reason
        rebuildMenu()

        guard fingerprintChanged || forceRequest else {
            logger.info("Ignored unchanged network fingerprint for \(reason, privacy: .public)")
            return
        }

        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.refreshWhenAllowed(reason: reason, forceRequest: forceRequest)
            }
        }
        debounceWorkItem = workItem

        if forceRequest {
            DispatchQueue.main.async(execute: workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
        }
    }

    private var nextAllowedRefreshDate: Date? {
        var dates: [Date] = []
        if let lastExternalRequestAt {
            dates.append(lastExternalRequestAt.addingTimeInterval(config.minimumRefreshInterval))
        }
        if let backoffUntil, backoffUntil > Date() {
            dates.append(backoffUntil)
        }
        return dates.max()
    }

    private func refreshWhenAllowed(reason: String, forceRequest: Bool = false) {
        scheduledRefreshWorkItem?.cancel()
        let now = Date()

        if !forceRequest, let nextAllowedRefreshDate, nextAllowedRefreshDate > now {
            let delay = nextAllowedRefreshDate.timeIntervalSince(now)
            let workItem = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.refreshWhenAllowed(reason: reason)
                }
            }
            scheduledRefreshWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            rebuildMenu()
            logger.info("Delayed refresh for \(reason, privacy: .public) by \(delay, privacy: .public)s")
            return
        }

        refreshNow(reason: reason)
    }

    private func refreshNow(reason: String) {
        fetchTask?.cancel()
        lastExternalRequestAt = Date()
        lastObservedReason = reason
        rebuildMenu()

        let request = makeRequest(for: config.sourceURL)
        let urlSession = makeURLSession()
        let logger = logger
        fetchTask = Task {
            defer {
                urlSession.invalidateAndCancel()
            }

            do {
                let (data, response) = try await urlSession.data(for: request)
                guard !Task.isCancelled else { return }

                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    throw FetchError.badStatus(httpResponse.statusCode)
                }

                let decoded = try JSONDecoder().decode(IPInfoResponse.self, from: data)
                logger.info("Fetched IP region data successfully")
                await MainActor.run {
                    self.backoffStep = 0
                    self.backoffUntil = nil
                    self.currentInfo = decoded
                    self.lastError = nil
                    self.lastUpdatedAt = Date()
                    self.updateStatusTitle(country: decoded.country)
                    self.rebuildMenu()
                }
            } catch is CancellationError {
                return
            } catch {
                logger.error("Fetch failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self.applyBackoff(for: error)
                    self.lastError = error.localizedDescription
                    self.updateStatusTitle(country: self.currentInfo?.country)
                    self.rebuildMenu()
                }
            }
        }
    }

    private func applyBackoff(for error: Error) {
        let baseDelay: TimeInterval
        if case FetchError.badStatus(let statusCode) = error {
            if statusCode == 403 || statusCode == 429 {
                baseDelay = 15 * 60
            } else if statusCode >= 500 {
                baseDelay = 5 * 60
            } else {
                return
            }
        } else {
            baseDelay = 2 * 60
        }

        backoffStep = min(backoffStep + 1, 5)
        let delay = min(baseDelay * pow(2, Double(backoffStep - 1)), 60 * 60)
        backoffUntil = Date().addingTimeInterval(delay)
    }

    private func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        configuration.httpShouldUsePipelining = false
        configuration.httpAdditionalHeaders = [
            "Cache-Control": "no-cache, no-store, max-age=0",
            "Pragma": "no-cache",
            "Expires": "0",
            "Connection": "close"
        ]
        return URLSession(configuration: configuration)
    }

    private func makeRequest(for sourceURL: URL) -> URLRequest {
        var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.removeAll { $0.name == "_ip_region_tray_nocache" }
        queryItems.append(URLQueryItem(name: "_ip_region_tray_nocache", value: UUID().uuidString))
        components?.queryItems = queryItems

        let requestURL = components?.url ?? sourceURL
        var request = URLRequest(url: requestURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 8
        request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("0", forHTTPHeaderField: "Expires")
        request.setValue("close", forHTTPHeaderField: "Connection")
        return request
    }

    private func updateStatusTitle(country: String?) {
        let title = country?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        statusItem.button?.title = title?.isEmpty == false ? title! : "--"

        if let currentInfo {
            let parts = [
                currentInfo.ip.map { "IP: \($0)" },
                currentInfo.country.map { "Country: \($0)" },
                currentInfo.region.map { "Region: \($0)" },
                currentInfo.timezone.map { "Timezone: \($0)" }
            ].compactMap { $0 }
            statusItem.button?.toolTip = parts.joined(separator: "\n")
        } else {
            statusItem.button?.toolTip = lastError ?? "IP Region Tray"
        }
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(config: config) { [weak self] newConfig in
                guard let self else { return }
                self.config = newConfig
                self.config.save()
                self.rebuildMenu()
                self.handleNetworkSignal(reason: "Settings changed", forceFingerprintChange: true, forceRequest: true)
            }
        }

        settingsWindowController?.config = config
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

enum FetchError: LocalizedError {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let statusCode):
            return "HTTP \(statusCode)"
        }
    }
}

struct NetworkFingerprint {
    static func current() -> String {
        var parts: [String] = []
        parts.append("proxies=\(stableDescription(SCDynamicStoreCopyProxies(nil)))")

        for key in [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6",
            "State:/Network/Global/DNS",
            "State:/Network/Global/Proxies",
            "Setup:/Network/Global/Proxies"
        ] {
            if let value = SCDynamicStoreCopyValue(nil, key as CFString) {
                parts.append("\(key)=\(stableDescription(value))")
            }
        }

        parts.append("interfaces=\(interfaceSnapshot())")
        let joined = parts.joined(separator: "\n")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func stableDescription(_ value: Any?) -> String {
        guard let value else { return "nil" }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: value)
    }

    private static func interfaceSnapshot() -> String {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return "unavailable"
        }
        defer { freeifaddrs(pointer) }

        var rows: [String] = []
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = current {
            defer { current = entry.pointee.ifa_next }
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP != 0 else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            guard !name.isEmpty else { continue }

            var family = "link"
            var address = ""
            if let socketAddress = entry.pointee.ifa_addr {
                switch Int32(socketAddress.pointee.sa_family) {
                case AF_INET:
                    family = "ipv4"
                    address = numericAddress(socketAddress)
                case AF_INET6:
                    family = "ipv6"
                    address = numericAddress(socketAddress)
                case AF_LINK:
                    family = "link"
                default:
                    continue
                }
            }

            rows.append("\(name):\(family):\(flags):\(address)")
        }

        return rows.sorted().joined(separator: "|")
    }

    private static func numericAddress(_ socketAddress: UnsafePointer<sockaddr>) -> String {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(socketAddress.pointee.sa_len)
        let result = getnameinfo(
            socketAddress,
            length,
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return "" }
        return String(cString: host)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    var config: AppConfig {
        didSet {
            sourceField.stringValue = config.sourceURL.absoluteString
            minimumIntervalField.doubleValue = config.minimumRefreshInterval
        }
    }

    private let onSave: (AppConfig) -> Void
    private let sourceField = NSTextField()
    private let minimumIntervalField = NSTextField()
    private let errorLabel = NSTextField(labelWithString: "")

    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 198),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "IP Region Tray Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        sourceField.stringValue = config.sourceURL.absoluteString
        sourceField.placeholderString = AppConfig.defaultURL

        minimumIntervalField.stringValue = String(Int(config.minimumRefreshInterval))
        minimumIntervalField.placeholderString = String(Int(AppConfig.defaultMinimumRefreshInterval))

        stack.addArrangedSubview(row(label: "Data source URL", control: sourceField))
        stack.addArrangedSubview(row(label: "Minimum refresh seconds", control: minimumIntervalField))

        errorLabel.textColor = .systemRed
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.maximumNumberOfLines = 2
        stack.addArrangedSubview(errorLabel)

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fill
        buttonStack.spacing = 8

        let spacer = NSView()
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded

        buttonStack.addArrangedSubview(spacer)
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(saveButton)
        stack.addArrangedSubview(buttonStack)

        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func row(label: String, control: NSControl) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 120).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 10
        return stack
    }

    @objc private func cancel() {
        window?.close()
    }

    @objc private func save() {
        let urlString = sourceField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let intervalString = minimumIntervalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            errorLabel.stringValue = "Please enter a valid URL."
            return
        }

        guard let interval = TimeInterval(intervalString),
              interval >= AppConfig.minimumAllowedRefreshInterval else {
            errorLabel.stringValue = "Minimum refresh seconds must be \(Int(AppConfig.minimumAllowedRefreshInterval)) or greater."
            return
        }

        errorLabel.stringValue = ""
        onSave(AppConfig(sourceURL: url, minimumRefreshInterval: interval))
        window?.close()
    }
}

@main
struct IPRegionTrayApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
