import Foundation
import Testing
@testable import ItemCatalogImport

@Suite struct RenameReaderTests {
    static let table = """
        <table><tbody><tr><td><p>Old Name</p></td><td><p>New Name</p></td></tr>
        <tr><td><p>Thunderstone</p></td><td><p>@UUID[Compendium.pf2e.equipment-srd.Item.Blasting Stone (Lesser)]\
        {Blasting Stone}</p></td></tr>
        <tr><td><p>Sunrod</p></td><td><p>@UUID[Compendium.pf2e.equipment-srd.Item.Glow Rod]</p></td></tr>
        <tr><td><p>Dragon's Breath potion (various)</p></td><td><p>Energy Breath Potion (various)</p></td></tr>
        <tr><td><p>Feather Token (Chest, Ladder)</p></td><td><p>Marvelous Miniatures \
        (@UUID[Compendium.pf2e.equipment-srd.Item.Marvelous Miniature (Chest)]{Chest}, \
        @UUID[Compendium.pf2e.equipment-srd.Item.Marvelous Miniature (Ladder)]{Ladder})</p></td></tr>
        <tr><td><p>Wyrm on the Wing, Wyrm on the Wing (Greater)</p></td><td><p>\
        @UUID[Compendium.pf2e.equipment-srd.Item.Wyrm's Wingspan], \
        @UUID[Compendium.pf2e.equipment-srd.Item.Wyrm's Wingspan (Greater)]</p></td></tr>
        <tr><td><p>Class Kits</p></td><td><p>Removed - There are now guidelines.</p></td></tr>
        </tbody></table>
        """

    @Test func readsEachKindOfRowInTheEquipmentTable() {
        #expect(RenameReader.renames(inTable: Self.table) == [
            "Thunderstone": "Blasting Stone (Lesser)", "Sunrod": "Glow Rod",
            "Dragon's Breath potion": "Energy Breath Potion",
            "Feather Token (Chest)": "Marvelous Miniature (Chest)",
            "Feather Token (Ladder)": "Marvelous Miniature (Ladder)",
            "Wyrm on the Wing": "Wyrm's Wingspan", "Wyrm on the Wing (Greater)": "Wyrm's Wingspan (Greater)"
        ])
    }

    @Test func keepsACommaInsideParenthesesWithItsName() {
        #expect(RenameReader.oldNames("Staff (Fire, Major), Wand") == ["Staff (Fire, Major)", "Wand"])
    }

    @Test func findsNoRenamesWithoutTheJournal() {
        #expect(RenameReader.renames(in: URL(fileURLWithPath: "/nonexistent")).isEmpty)
    }

    @Test func importsTheRenamesBesideTheItems() throws {
        let repository = try FixtureRepository()
        try repository.addItem(Documents.potion)
        let journal: [String: Any] = ["pages": [["name": "Equipment", "text": ["content": Self.table]]]]
        let data = try JSONSerialization.data(withJSONObject: journal)
        try repository.write(String(bytes: data, encoding: .utf8) ?? "", to: RenameReader.journal)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("generated-\(UUID().uuidString)")
        let report = try ItemImporter(repository: repository.root, outputDirectory: output).run()
        #expect(report.renameCount == 7 && report.markdown.contains("7 remaster renames"))
        let renames = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: output
            .appendingPathComponent("Items/renames.json")))
        #expect(renames["Sunrod"] == "Glow Rod")
    }
}
