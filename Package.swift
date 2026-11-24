// swift-tools-version: 6.0
import PackageDescription

// An app extension has no main: it starts in Foundation's NSExtensionMain, which loads its principal class.
let quickLookExtension: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"]),
    .linkedFramework("QuickLookThumbnailing"), .linkedFramework("QuickLookUI", .when(platforms: [.macOS]))
]

let package = Package(
    name: "PawnShop",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .executable(name: "PawnShop", targets: ["PawnShop"]),
        .executable(name: "ItemImport", targets: ["ItemImport"]),
        .library(name: "PawnShopCore", targets: ["PawnShopCore"]),
        // The app shared by the Mac executable and the iPad project in ios/.
        .library(name: "PawnShopUI", targets: ["PawnShopUI"]),
        // What the Quick Look extensions read from a sheet's file, without the library.
        .library(name: "SheetPreviewFile", targets: ["SheetPreviewFile"]),
        // The Mac's Quick Look extensions, which scripts/build-app.sh bundles; the iPad project builds their sources.
        .executable(name: "PawnShopThumbnail", targets: ["PawnShopThumbnail"]),
        .executable(name: "PawnShopPreview", targets: ["PawnShopPreview"])
    ],
    dependencies: [
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "1.19.0")
    ],
    targets: [
        .target(name: "SheetPreviewFile"),
        .executableTarget(name: "PawnShopThumbnail", dependencies: ["SheetPreviewFile"],
                          linkerSettings: quickLookExtension),
        .executableTarget(name: "PawnShopPreview", dependencies: ["SheetPreviewFile"],
                          linkerSettings: quickLookExtension),
        .target(name: "PawnShopCore", dependencies: [
            "SheetPreviewFile",
            .product(name: "ArtExtraction", package: "tabletop-kit"),
            .product(name: "SharedLibraries", package: "tabletop-kit"),
            .product(name: "TablesideShared", package: "tabletop-kit"),
            .product(name: "TablesideSync", package: "tabletop-kit")
        ]),
        .target(name: "PawnShopUI", dependencies: [
            "PawnShopCore", "SheetPreviewFile", .product(name: "AppNotices", package: "tabletop-kit"),
            .product(name: "SharedLibraries", package: "tabletop-kit"),
            .product(name: "TablesideShared", package: "tabletop-kit"),
            .product(name: "TablesideSync", package: "tabletop-kit"),
            .product(name: "TablesideSyncUI", package: "tabletop-kit")
        ]),
        .executableTarget(name: "PawnShop", dependencies: ["PawnShopUI"]),
        .target(name: "ItemCatalogImport", dependencies: [
            "PawnShopCore", .product(name: "CreatureImport", package: "tabletop-kit"),
            .product(name: "Bestiary", package: "tabletop-kit")
        ]),
        .executableTarget(name: "ItemImport", dependencies: ["ItemCatalogImport"]),
        .testTarget(name: "PawnShopCoreTests", dependencies: [
            "PawnShopCore", "SheetPreviewFile", .product(name: "ArtExtractionTestSupport", package: "tabletop-kit"),
            .product(name: "SharedLibraries", package: "tabletop-kit"),
            .product(name: "TablesideShared", package: "tabletop-kit"),
            .product(name: "TablesideSync", package: "tabletop-kit")
        ]),
        .testTarget(name: "ItemCatalogImportTests", dependencies: ["ItemCatalogImport"]),
        .testTarget(name: "SheetPreviewFileTests", dependencies: ["SheetPreviewFile"])
    ]
)
