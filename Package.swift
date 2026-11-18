// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PawnShop",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .executable(name: "PawnShop", targets: ["PawnShop"]),
        .executable(name: "ItemImport", targets: ["ItemImport"]),
        .library(name: "PawnShopCore", targets: ["PawnShopCore"]),
        // The app shared by the Mac executable and the iPad project in ios/.
        .library(name: "PawnShopUI", targets: ["PawnShopUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "1.11.1")
    ],
    targets: [
        .target(name: "PawnShopCore", dependencies: [
            .product(name: "ArtExtraction", package: "tabletop-kit"),
            .product(name: "SharedLibraries", package: "tabletop-kit"),
            .product(name: "TablesideShared", package: "tabletop-kit")
        ]),
        .target(name: "PawnShopUI", dependencies: [
            "PawnShopCore", .product(name: "AppNotices", package: "tabletop-kit"),
            .product(name: "TablesideShared", package: "tabletop-kit")
        ]),
        .executableTarget(name: "PawnShop", dependencies: ["PawnShopUI"]),
        .target(name: "ItemCatalogImport", dependencies: [
            "PawnShopCore", .product(name: "CreatureImport", package: "tabletop-kit"),
            .product(name: "Bestiary", package: "tabletop-kit")
        ]),
        .executableTarget(name: "ItemImport", dependencies: ["ItemCatalogImport"]),
        .testTarget(name: "PawnShopCoreTests", dependencies: [
            "PawnShopCore", .product(name: "ArtExtractionTestSupport", package: "tabletop-kit"),
            .product(name: "SharedLibraries", package: "tabletop-kit"),
            .product(name: "TablesideShared", package: "tabletop-kit")
        ]),
        .testTarget(name: "ItemCatalogImportTests", dependencies: ["ItemCatalogImport"])
    ]
)
