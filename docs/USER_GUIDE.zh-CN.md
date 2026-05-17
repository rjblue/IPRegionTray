# IPRegionTray 使用说明

[English](USER_GUIDE.md) | [简体中文](USER_GUIDE.zh-CN.md)

IPRegionTray 是一个原生 macOS 菜单栏应用，用来显示当前公网 IP 所在国家或地区代码，例如 `SG`。

## 系统要求

- macOS 13 或更高版本
- Apple Silicon / ARM 处理器

## 快速使用

1. 打开 `app/IPRegionTray.app`。
2. 在 macOS 顶部菜单栏右侧查看地球图标旁边的国家代码。
3. 点击菜单栏图标可以查看当前 IP、地区、数据源、上次刷新时间，也可以手动刷新或打开设置。

## 默认行为

- 默认数据源：`https://ipinfo.io/json`
- 默认刷新频率：每 `3` 秒刷新一次
- 网络环境变化时，会立即触发一次刷新
- 每次请求都会追加随机 query 参数，避免拿到缓存数据

## 配置

点击菜单栏图标，选择 `Settings...`，可以修改：

- Data source URL：数据源 URL
- Refresh seconds：刷新间隔秒数

配置会保存到 macOS `UserDefaults`。

## 退出

点击菜单栏图标，选择 `Quit IP Region Tray`。

## 如果打不开

如果 macOS 提示无法验证开发者，可以在系统设置的隐私与安全性里允许打开，或者右键点击 `IPRegionTray.app` 后选择打开。
