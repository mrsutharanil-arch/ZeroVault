// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZeroVault",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ZeroVault",
            targets: ["ZeroVault"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ZeroVault",
            path: "ZeroVault",
            exclude: ["App/Info.plist"]
        ),
    ]
)
