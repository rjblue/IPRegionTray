# IPRegionTray 1.0.0

Initial public release of IPRegionTray.

IPRegionTray is a native macOS menu bar app that shows your current public IP region, designed especially for people who use AI tools, VPNs, proxies, and regional developer services.

## Highlights

- Shows current IP country code in the macOS menu bar.
- Defaults to `https://ipinfo.io/json`.
- Refreshes every 3 seconds.
- Refreshes immediately when the network path changes.
- Configurable data source and refresh interval.
- Avoids stale data with a random no-cache query and fresh ephemeral requests.
- Apple Silicon `arm64` binary included.

## Package Contents

```text
IPRegionTray-1.0.0/
  app/IPRegionTray.app
  executable/IPRegionTray-arm64
  source/
  docs/
  SHA256SUMS.txt
```

## Installation

1. Download `IPRegionTray-1.0.0-mac-arm64.zip`.
2. Unzip it.
3. Open `app/IPRegionTray.app`.

If macOS blocks the app, right-click it and choose `Open`.

## Contact

Maintainer: Jake  
Email: rjblue@qq.com
