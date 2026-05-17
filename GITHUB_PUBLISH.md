# GitHub Publish Checklist

Use this file when publishing IPRegionTray to GitHub.

## Repository

Recommended repository name:

```text
IPRegionTray
```

Description:

```text
Native macOS menu bar app that shows your current public IP region, useful for AI tools, VPNs, proxies, and standalone IP region checks.
```

Visibility:

```text
Public
```

Topics:

```text
macos
menubar
swift
appkit
ipinfo
ip-region
vpn
proxy
ai-tools
apple-silicon
```

Website:

```text
Leave empty unless you add a project homepage later.
```

## Release

Tag:

```text
v1.0.0
```

Title:

```text
IPRegionTray 1.0.0
```

Release notes:

Use the contents of:

```text
RELEASE_NOTES_v1.0.0.md
```

Release asset:

```text
release/IPRegionTray-1.0.0-mac-arm64.zip
```

## Local Commands

If GitHub CLI is authenticated:

```bash
git remote add origin git@github.com:<owner>/IPRegionTray.git
git push -u origin main
git tag v1.0.0
git push origin v1.0.0
gh release create v1.0.0 release/IPRegionTray-1.0.0-mac-arm64.zip \
  --title "IPRegionTray 1.0.0" \
  --notes-file RELEASE_NOTES_v1.0.0.md
```

If using HTTPS:

```bash
git remote add origin https://github.com/<owner>/IPRegionTray.git
git push -u origin main
git tag v1.0.0
git push origin v1.0.0
```

Then create the release on GitHub and upload:

```text
release/IPRegionTray-1.0.0-mac-arm64.zip
```
