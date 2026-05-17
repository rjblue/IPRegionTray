// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "IPRegionTray",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "IPRegionTray", targets: ["IPRegionTray"])
    ],
    targets: [
        .executableTarget(
            name: "IPRegionTray",
            path: "Sources/IPRegionTray"
        )
    ]
)
