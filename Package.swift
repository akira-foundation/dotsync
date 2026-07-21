// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dotsync",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
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
            dependencies: [
                "DotSyncCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "DotSyncCoreTests",
            dependencies: ["DotSyncCore"]
        ),
    ]
)
