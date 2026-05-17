# IPRegionTray 开发说明

[English](DEV_GUIDE.md) | [简体中文](DEV_GUIDE.zh-CN.md)

这是一个 Swift Package 项目，使用 AppKit 和 Network.framework 实现原生 macOS 菜单栏应用。

## 目录

- `Package.swift`：SwiftPM 项目配置
- `Sources/IPRegionTray/main.swift`：应用源码
- `Resources/Info.plist`：macOS app bundle 配置
- `scripts/build-app.sh`：构建 `.app` 的脚本
- `scripts/package-release.sh`：生成 release zip 的脚本
- `.github/workflows/build.yml`：GitHub Actions 构建验证

## 构建

在项目根目录执行：

```bash
./scripts/build-app.sh
```

构建产物：

```text
dist/IPRegionTray.app
```

## 运行

```bash
open dist/IPRegionTray.app
```

## 生成发布包

```bash
./scripts/package-release.sh 1.0.0
```

发布包位置：

```text
release/IPRegionTray-1.0.0-mac-arm64.zip
```

## 关键实现

- `NSStatusItem`：显示菜单栏图标和国家代码
- `URLSessionConfiguration.ephemeral`：避免使用持久缓存
- 随机 `_ip_region_tray_nocache` query：强制每次请求唯一 URL
- `NWPathMonitor`：监听系统网络路径变化
- `UserDefaults`：保存数据源和刷新频率
