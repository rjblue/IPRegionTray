# IPRegionTray

[English](README.md) | [简体中文](README.zh-CN.md)

IPRegionTray 是一个原生 macOS 菜单栏应用，用来随时查看当前公网 IP 所属 Region。

它特别适合在使用各种 AI 工具、代理、VPN、远程工作区和区域化服务时确认当前网络出口。你不需要打开浏览器，就可以直接在 macOS 顶部菜单栏看到当前 IP 对应的国家或地区代码。它也可以作为一个独立的 Mac 小工具，用来查看公网 IP 地区。

## 截图示意

菜单栏显示：

```text
🌐 SG
```

菜单详情：

```text
Country: SG
IP: 103.211.230.150
Region: Singapore
Source: https://ipinfo.io/json
Refresh: 3s
Last updated: 14:42:10
```

## 为什么做这个

很多 AI 产品、编程助手、模型服务、云控制台和开发者工具都会受到当前网络 Region 的影响。用浏览器查当然可以，但会打断工作流。IPRegionTray 把这个信息固定在菜单栏里，让你随时扫一眼就知道当前出口在哪里。

典型场景：

- 使用 AI 工具时确认当前网络 Region。
- 检查 VPN、代理或远程网络路由是否生效。
- 网络切换后快速发现公网 IP Region 变化。
- 作为独立的 macOS IP Region 监控工具使用。

## 功能

- Swift + AppKit 原生 macOS 菜单栏应用。
- 读取 `https://ipinfo.io/json` 返回的 `country` 字段，例如 `SG`。
- 默认每 `3` 秒刷新一次。
- 数据源 URL 和刷新间隔可配置。
- macOS 检测到网络路径变化时立即刷新。
- 每次请求都会追加随机无意义 query，避免缓存导致的旧数据。
- 不显示 Dock 图标，只驻留在菜单栏。
- 支持 Apple Silicon `arm64`。

## 下载

从 GitHub Releases 下载最新二进制包。

发布包结构：

```text
IPRegionTray-1.0.0/
  app/                 IPRegionTray.app
  executable/          独立 arm64 可执行文件
  source/              源码和构建脚本
  docs/                中英文文档
  SHA256SUMS.txt       文件校验
```

## 安装

1. 从 Releases 下载 `IPRegionTray-1.0.0-mac-arm64.zip`。
2. 解压。
3. 打开 `app/IPRegionTray.app`。

如果 macOS 提示无法验证开发者，可以右键点击 `IPRegionTray.app`，选择 `打开`，再确认打开。

## 使用

点击菜单栏图标可以：

- 查看 IP、国家或地区代码、Region、城市、组织和上次刷新时间
- 手动刷新
- 打开设置
- 退出应用

打开 `Settings...` 可以修改：

- 数据源 URL
- 刷新间隔秒数

配置会保存到 macOS `UserDefaults`。

更多文档：

- [使用说明](docs/USER_GUIDE.zh-CN.md)
- [开发说明](docs/DEV_GUIDE.zh-CN.md)

## 数据源

默认接口：

```text
https://ipinfo.io/json
```

期望 JSON 结构：

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

IPRegionTray 会读取顶层 `country` 字段并显示在菜单栏。

为了避免旧数据，每次刷新都会追加一个随机 query：

```text
_ip_region_tray_nocache=<UUID>
```

同时还会使用 no-cache 请求头和全新的 ephemeral URL session。

## 从源码构建

要求：

- macOS 13 或更高版本
- Xcode Command Line Tools
- Apple Silicon Mac

构建：

```bash
./scripts/build-app.sh
```

运行：

```bash
open dist/IPRegionTray.app
```

## 隐私

IPRegionTray 只会请求你配置的数据源。默认数据源是 `https://ipinfo.io/json`。应用不收集分析数据，不启动本地服务，也不会把数据发送到其他地方。

## 联系

Maintainer: Jake  
Email: rjblue@qq.com

## License

MIT License. See [LICENSE](LICENSE).
