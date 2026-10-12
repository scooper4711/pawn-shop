// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PawnShop",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "PawnShop", targets: ["PawnShop"]),
        .executable(name: "ItemImport", targets: ["ItemImport"]),
        .library(name: "PawnShopCore", targets: ["PawnShopCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "0.8.0")
    ],
    targets: [
        .target(name: "PawnShopCore", dependencies: [.product(name: "ArtExtraction", package: "tabletop-kit")]),
        .executableTarget(name: "PawnShop", dependencies: ["PawnShopCore"]),
        .target(name: "ItemCatalogImport", dependencies: [
            "PawnShopCore", .product(name: "CreatureImport", package: "tabletop-kit"),
            .product(name: "Bestiary", package: "tabletop-kit")
        ]),
        .executableTarget(name: "ItemImport", dependencies: ["ItemCatalogImport"]),
        .testTarget(name: "PawnShopCoreTests", dependencies: [
            "PawnShopCore", .product(name: "ArtExtractionTestSupport", package: "tabletop-kit")
        ]),
        .testTarget(name: "ItemCatalogImportTests", dependencies: ["ItemCatalogImport"])
    ]
)
