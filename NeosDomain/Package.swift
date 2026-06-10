// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NeosDomain",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "NeosDomain", targets: ["NeosDomain"])
    ],
    targets: [
        .target(
            name: "NeosDomain",
            path: "Sources/NeosDomain"
        ),
        .testTarget(
            name: "NeosDomainTests",
            dependencies: ["NeosDomain"],
            path: "Tests/NeosDomainTests"
        )
    ]
)
