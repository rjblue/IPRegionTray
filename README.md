# IPRegionTray

[English](README.md) | [简体中文](README.zh-CN.md)

Native macOS menu bar app that shows your current public IP region at a glance.

IPRegionTray was built for people who use AI tools, proxies, VPNs, remote workspaces, and regional services every day. When your network route changes, it is useful to know which country or region your current public IP is using without opening a browser. It is also a simple standalone macOS utility for checking your IP region from the menu bar.

## Screenshots

Menu bar display:

```text
🌐 SG
```

Menu details:

```text
Country: SG
IP: 103.211.230.150
Region: Singapore
Source: https://ipinfo.io/json
Refresh: event-driven
Minimum interval: 60s
Last updated: 14:42:10
```

## Why

Many AI products, coding assistants, model providers, cloud consoles, and developer tools behave differently depending on the current network region. A browser tab can tell you the answer, but it is slow context-switching. IPRegionTray keeps the answer in the macOS menu bar.

Typical use cases:

- Check the active region while using AI tools.
- Verify VPN, proxy, or remote network routing.
- Notice when a network switch changed the public IP region.
- Use it as a small standalone IP region monitor on macOS.

## Features

- Native macOS menu bar app built with Swift and AppKit.
- Shows the `country` field from `https://ipinfo.io/json`, for example `SG`.
- Event-driven refresh instead of constant polling.
- Watches macOS network path, proxy, DNS, interface, virtual adapter, and wake events.
- Data source URL and minimum refresh interval are configurable.
- Default minimum external request interval is `60` seconds.
- Uses backoff after rate-limit, blocked, server, or network errors.
- Uses a fresh ephemeral URL session and a random no-cache query on every request.
- No Dock icon; it lives quietly in the menu bar.
- Apple Silicon `arm64` build.

## Download

Download the latest binary package from GitHub Releases.

The release package contains:

```text
IPRegionTray-1.1.0/
  app/                 IPRegionTray.app
  executable/          standalone arm64 executable
  source/              source code and build script
  docs/                English and Chinese docs
  SHA256SUMS.txt       file checksums
```

## Install

1. Download `IPRegionTray-1.1.0-mac-arm64.zip` from Releases.
2. Unzip it.
3. Open `app/IPRegionTray.app`.

If macOS says the developer cannot be verified, right-click `IPRegionTray.app`, choose `Open`, then confirm.

## Usage

Click the menu bar item to:

- view IP, country, region, city, org, and last update time
- refresh manually
- open settings
- quit the app

Open `Settings...` to change:

- data source URL
- minimum refresh interval in seconds

Settings are stored in macOS `UserDefaults`.

More documentation:

- [User Guide](docs/USER_GUIDE.md)
- [Developer Guide](docs/DEV_GUIDE.md)

## Data Source

Default endpoint:

```text
https://ipinfo.io/json
```

Expected JSON shape:

```json
{
  "ip": "103.211.230.150",
  "city": "Singapore",
  "region": "Singapore",
  "country": "SG",
  "loc": "1.2897,103.8501",
  "org": "AS135391 AOFEI DATA INTERNATIONAL COMPANY LIMITED",
  "postal": "018989",
  "timezone": "Asia/Singapore"
}
```

IPRegionTray reads the top-level `country` field and displays it in the menu bar.

IPRegionTray does not poll the endpoint on a timer. It builds a local network fingerprint from macOS network state, proxy settings, DNS settings, and active interfaces. When that fingerprint changes, it debounces the signal and refreshes only after the configured minimum interval allows another external request. This catches changes such as VPN/proxy mode switches, PAC/global proxy changes, DNS changes, interface changes, virtual adapter changes, and wake-from-sleep events without continuously hitting the data source.

To avoid stale data, every refresh adds a meaningless random query parameter:

```text
_ip_region_tray_nocache=<UUID>
```

It also uses no-cache headers and a fresh ephemeral URL session.

## Build From Source

Requirements:

- macOS 13 or later
- Xcode Command Line Tools
- Apple Silicon Mac

Build:

```bash
./scripts/build-app.sh
```

Run:

```bash
open dist/IPRegionTray.app
```

The app bundle is created at:

```text
dist/IPRegionTray.app
```

## Release Package

Create a local release package:

```bash
./scripts/build-app.sh
```

Create a release-style package:

```bash
./scripts/package-release.sh 1.1.0
```

## Project Structure

```text
Package.swift
Resources/Info.plist
Sources/IPRegionTray/main.swift
docs/
scripts/build-app.sh
```

## Privacy

IPRegionTray requests the configured IP info endpoint from your Mac. By default, that endpoint is `https://ipinfo.io/json`. The app does not collect analytics, does not run a background server, and does not send data anywhere else.

## Contact

Maintainer: Jake  
Email: rjblue@qq.com

## License

MIT License. See [LICENSE](LICENSE).
