// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dotsync",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "DotSyncCore",
            resources: [.copy("Resources/json-merge.sh")]
        ),
        .executableTarget(
            name: "DotSyncCLI",
            dependencies: ["DotSyncCore"]
        ),
        .executableTarget(
            name: "DotSyncApp",
            dependencies: ["DotSyncCore"]
        ),
        .testTarget(
            name: "DotSyncCoreTests",
            dependencies: ["DotSyncCore"]
        ),
    ]
)
