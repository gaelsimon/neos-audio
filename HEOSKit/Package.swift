// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HEOSKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "HEOSKit", targets: ["HEOSKit"])
    ],
    dependencies: [
        .package(path: "../NeosDomain")
    ],
    targets: [
        .target(
            name: "HEOSKit",
            dependencies: [
                .product(name: "NeosDomain", package: "NeosDomain")
            ],
            path: "Sources/HEOSKit"
        ),
        .testTarget(
            name: "HEOSKitTests",
            dependencies: ["HEOSKit"],
            path: "Tests/HEOSKitTests"
        )
    ]
)
