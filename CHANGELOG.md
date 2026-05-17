# Changelog

All notable changes to IPRegionTray are documented here.

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
