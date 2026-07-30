// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "slskdbar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SlskdMenuCore", targets: ["SlskdMenuCore"]),
        .executable(name: "slskdbar", targets: ["SlskdMenuApp"]),
    ],
    targets: [
        .target(name: "SlskdMenuCore"),
        .executableTarget(
            name: "SlskdMenuApp",
            dependencies: ["SlskdMenuCore"],
            path: "Sources/SlskdMenuApp"
        ),
        .testTarget(name: "SlskdMenuCoreTests", dependencies: ["SlskdMenuCore"]),
    ]
)
