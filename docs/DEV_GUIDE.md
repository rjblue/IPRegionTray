# IPRegionTray Developer Guide

[English](DEV_GUIDE.md) | [简体中文](DEV_GUIDE.zh-CN.md)

IPRegionTray is a Swift Package project that uses AppKit and Network.framework to build a native macOS menu bar app.

## Project Structure

- `Package.swift`: SwiftPM project configuration
- `Sources/IPRegionTray/main.swift`: app source code
- `Resources/Info.plist`: macOS app bundle metadata
- `scripts/build-app.sh`: builds `dist/IPRegionTray.app`
- `scripts/package-release.sh`: creates the release zip package
- `.github/workflows/build.yml`: GitHub Actions build verification

## Build

Run from the project root:

```bash
./scripts/build-app.sh
```

Build output:

```text
dist/IPRegionTray.app
```

## Run

```bash
open dist/IPRegionTray.app
```

## Create a Release Package

```bash
./scripts/package-release.sh 1.1.0
```

Package output:

```text
release/IPRegionTray-1.1.0-mac-arm64.zip
```

## Implementation Notes

- `NSStatusItem` renders the menu bar icon and country code.
- `URLSessionConfiguration.ephemeral` avoids persistent cache state.
- `_ip_region_tray_nocache=<UUID>` makes each request URL unique.
- `NWPathMonitor` captures network path changes.
- `SCDynamicStore` captures proxy, DNS, interface, virtual adapter, IPv4, and IPv6 changes.
- `NSWorkspace.didWakeNotification` catches wake-from-sleep changes.
- `NetworkFingerprint` hashes local network state so external requests happen only when meaningful state changes.
- A debounced minimum interval and error backoff prevent high-frequency endpoint access.
- `UserDefaults` stores the data source URL and minimum refresh interval.
