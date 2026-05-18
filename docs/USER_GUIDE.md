# IPRegionTray User Guide

[English](USER_GUIDE.md) | [简体中文](USER_GUIDE.zh-CN.md)

IPRegionTray is a native macOS menu bar app that shows the country or region code of your current public IP, for example `SG`.

## Requirements

- macOS 13 or later
- Apple Silicon / ARM Mac

## Quick Start

1. Open `app/IPRegionTray.app`.
2. Look at the right side of the macOS menu bar.
3. The globe icon shows the current IP country code beside it.
4. Click the menu bar item to view IP details, refresh manually, open settings, or quit.

## Default Behavior

- Default data source: `https://ipinfo.io/json`
- Event-driven refresh instead of fixed polling
- Default minimum external request interval: `60` seconds
- Watches network path, proxy, DNS, interface, virtual adapter, and wake events
- Adds a random query parameter on every request to avoid stale cached data
- Uses automatic backoff after rate-limit, blocked, server, or network errors

## Settings

Open the menu bar item and choose `Settings...`.

You can change:

- Data source URL
- Minimum refresh interval in seconds

Settings are saved in macOS `UserDefaults`.

## Menu Actions

- `Refresh Now`: fetch the latest IP info immediately
- `Settings...`: configure data source and minimum refresh interval
- `Quit IP Region Tray`: exit the app

## If macOS Blocks the App

If macOS says the developer cannot be verified, right-click `IPRegionTray.app`, choose `Open`, then confirm.
