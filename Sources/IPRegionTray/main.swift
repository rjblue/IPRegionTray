import AppKit
import Foundation
import Network
import OSLog

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
    static let defaultRefreshInterval: TimeInterval = 3
    static let urlKey = "sourceURL"
    static let refreshIntervalKey = "refreshInterval"

    var sourceURL: URL
    var refreshInterval: TimeInterval

    static func load() -> AppConfig {
        let defaults = UserDefaults.standard
        let urlString = defaults.string(forKey: urlKey) ?? defaultURL
        let sourceURL = URL(string: urlString) ?? URL(string: defaultURL)!
        let savedInterval = defaults.double(forKey: refreshIntervalKey)
        let refreshInterval = savedInterval > 0 ? savedInterval : defaultRefreshInterval
        return AppConfig(sourceURL: sourceURL, refreshInterval: max(1, refreshInterval))
    }

    func save() {
        UserDefaults.standard.set(sourceURL.absoluteString, forKey: Self.urlKey)
        UserDefaults.standard.set(refreshInterval, forKey: Self.refreshIntervalKey)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.rjblue.IPRegionTray", category: "network")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "ip-region-tray.network-monitor")
    private var refreshTimer: Timer?
    private var settingsWindowController: SettingsWindowController?
    private var config = AppConfig.load()
    private var currentInfo: IPInfoResponse?
    private var lastError: String?
    private var lastUpdatedAt: Date?
    private var fetchTask: Task<Void, Never>?
    private var didReceiveFirstNetworkPath = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        startRefreshTimer()
        startNetworkMonitor()
        refreshNow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        monitor.cancel()
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
        menu.addItem(disabledItem("Refresh: \(formatInterval(config.refreshInterval))"))
        if let lastUpdatedAt {
            menu.addItem(disabledItem("Last updated: \(formatDate(lastUpdatedAt))"))
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

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: config.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.didReceiveFirstNetworkPath {
                    self.refreshNow()
                }
                self.didReceiveFirstNetworkPath = true
            }
        }
        monitor.start(queue: monitorQueue)
    }

    @objc private func refreshNowFromMenu() {
        refreshNow()
    }

    private func refreshNow() {
        fetchTask?.cancel()

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
                logger.info("Fetched ip=\(decoded.ip ?? "--", privacy: .public) country=\(decoded.country ?? "--", privacy: .public)")
                await MainActor.run {
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
                    self.lastError = error.localizedDescription
                    self.updateStatusTitle(country: nil)
                    self.rebuildMenu()
                }
            }
        }
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
                self.startRefreshTimer()
                self.rebuildMenu()
                self.refreshNow()
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

@MainActor
final class SettingsWindowController: NSWindowController {
    var config: AppConfig {
        didSet {
            sourceField.stringValue = config.sourceURL.absoluteString
            intervalField.doubleValue = config.refreshInterval
        }
    }

    private let onSave: (AppConfig) -> Void
    private let sourceField = NSTextField()
    private let intervalField = NSTextField()
    private let errorLabel = NSTextField(labelWithString: "")

    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 184),
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

        intervalField.stringValue = String(Int(config.refreshInterval))
        intervalField.placeholderString = "3"

        stack.addArrangedSubview(row(label: "Data source URL", control: sourceField))
        stack.addArrangedSubview(row(label: "Refresh seconds", control: intervalField))

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
        let intervalString = intervalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            errorLabel.stringValue = "Please enter a valid URL."
            return
        }

        guard let interval = TimeInterval(intervalString), interval >= 1 else {
            errorLabel.stringValue = "Refresh seconds must be 1 or greater."
            return
        }

        errorLabel.stringValue = ""
        onSave(AppConfig(sourceURL: url, refreshInterval: interval))
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
