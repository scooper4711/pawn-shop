// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PawnShop",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "PawnShop", targets: ["PawnShop"]),
        .library(name: "PawnShopCore", targets: ["PawnShopCore"]),
    ],
    targets: [
        .target(name: "PawnShopCore"),
        .executableTarget(name: "PawnShop", dependencies: ["PawnShopCore"]),
        .testTarget(name: "PawnShopCoreTests", dependencies: ["PawnShopCore"]),
    ]
)
