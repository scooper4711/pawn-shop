import Foundation
import Testing
@testable import ItemCatalogImport
import PawnShopCore

@Suite struct ItemImporterTests {
    let repository: FixtureRepository
    let output = FileManager.default.temporaryDirectory.appendingPathComponent("generated-\(UUID().uuidString)")

    init() throws {
        repository = try FixtureRepository()
        for document in [Documents.potion, Documents.longsword, Documents.fullPlate, Documents.shield] {
            try repository.addItem(document)
        }
        try repository.addItem(Documents.laser, game: "sf2e", folder: "weapons")
        try repository.addItem(Documents.item("Unarmed", type: "weapon", system: [:]), game: "sf2e",
                               folder: "virtual-items")
        try repository.addItem(Documents.item("Fire Effect", type: "effect", system: [:]))
    }

    @Test func writesEveryItemSortedWithItsLicensesAndReport() throws {
        let report = try ItemImporter(repository: repository.root, outputDirectory: output).run()
        #expect(report.itemCount == 5 && report.kinds[.weapon] == 2 && report.markdown.contains("5 items."))
        let catalog = ItemCatalog(contentsOf: output.appendingPathComponent("Items/items.json"))
        #expect(catalog.items.map(\.name)
                == ["Full Plate", "Healing Potion", "Longsword", "Steel Shield", "Laser Pistol"])
        #expect(catalog.items.last?.id == "starfinder/LaserPistol" && catalog.items.last?.game == .starfinder)
        let licenses = output.appendingPathComponent("Items/Licenses")
        #expect(try FileManager.default.contentsOfDirectory(atPath: licenses.path).sorted()
                == ["ORCLicense.md", "OpenGameLicense.md"])
    }

    @Test func importingTwiceGivesTheSameBytes() throws {
        let importer = ItemImporter(repository: repository.root, outputDirectory: output)
        try importer.run()
        let first = try Data(contentsOf: output.appendingPathComponent("Items/items.json"))
        try importer.run()
        #expect(try Data(contentsOf: output.appendingPathComponent("Items/items.json")) == first)
    }

    @Test func reportsAMissingRepository() {
        let importer = ItemImporter(repository: output.appendingPathComponent("missing"), outputDirectory: output)
        #expect(throws: (any Error).self) { try importer.run() }
    }
}
