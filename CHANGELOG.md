# Changelog

All notable changes to IPRegionTray are documented here.

## 1.1.0 - 2026-05-18

- Replace fixed 3-second polling with event-driven refresh.
- Watch macOS network path, proxy, DNS, interface, virtual adapter, and wake events.
- Add local network fingerprinting so unchanged signals do not trigger external requests.
- Add configurable minimum external request interval, defaulting to 60 seconds.
- Add automatic backoff for rate-limit, blocked, server, and network errors.
- Keep the last known country visible when transient refresh errors occur.
- Stop logging fetched public IP addresses to macOS unified logging.
- Keep no-cache query parameters, no-cache headers, and ephemeral sessions for fresh responses.
- Update English and Chinese documentation.

## 1.0.0 - 2026-05-17

Initial public release.

- Add native macOS menu bar app for Apple Silicon.
- Show current IP `country` code from `https://ipinfo.io/json`.
- Refresh every 3 seconds by default.
- Allow configuring data source URL and refresh interval.
- Refresh immediately when macOS network path changes.
- Add random no-cache query parameter on every request.
- Use fresh ephemeral URL sessions to avoid stale responses.
- Add release package with app bundle, executable, source, docs, and checksums.
