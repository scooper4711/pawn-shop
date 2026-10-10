// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PawnShop",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "PawnShop", targets: ["PawnShop"]),
        .library(name: "PawnShopCore", targets: ["PawnShopCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "0.2.0")
    ],
    targets: [
        .target(name: "PawnShopCore", dependencies: [.product(name: "ArtExtraction", package: "tabletop-kit")]),
        .executableTarget(name: "PawnShop", dependencies: ["PawnShopCore"]),
        .testTarget(name: "PawnShopCoreTests", dependencies: [
            "PawnShopCore", .product(name: "ArtExtractionTestSupport", package: "tabletop-kit")
        ])
    ]
)
