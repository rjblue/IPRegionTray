# IPRegionTray 1.1.0

This release changes IPRegionTray from fixed polling to event-driven refresh so the app can detect meaningful network route changes without repeatedly hitting the IP data source.

## What's New

- Replaced 3-second polling with event-driven refresh.
- Watches macOS network path, proxy, DNS, interface, virtual adapter, IPv4, IPv6, and wake events.
- Adds local network fingerprinting to ignore duplicate or irrelevant signals.
- Adds a configurable minimum external request interval, defaulting to 60 seconds.
- Adds automatic backoff after rate-limit, blocked, server, or network errors.
- Keeps the last known country visible when a transient refresh fails.
- Stops logging fetched public IP addresses to macOS unified logging.
- Keeps no-cache query parameters, no-cache headers, and ephemeral sessions for fresh responses.

## Download

Use the Apple Silicon build:

```text
IPRegionTray-1.1.0-mac-arm64.zip
```

Package contents:

```text
IPRegionTray-1.1.0/
  app/                 IPRegionTray.app
  executable/          standalone arm64 executable
  source/              source code and build script
  docs/                English and Chinese docs
  SHA256SUMS.txt       file checksums
```

## Install

1. Download `IPRegionTray-1.1.0-mac-arm64.zip`.
2. Unzip it.
3. Open `app/IPRegionTray.app`.

If macOS blocks the app because it is not notarized, right-click `IPRegionTray.app`, choose `Open`, then confirm.

## Privacy

IPRegionTray only requests the configured IP information endpoint. It does not collect analytics, does not run a background server, and does not send data anywhere else.
