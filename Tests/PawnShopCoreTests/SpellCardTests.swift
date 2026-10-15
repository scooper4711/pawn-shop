import CoreGraphics
import Foundation
import PDFKit
import Testing
import ArtExtraction
import ArtExtractionTestSupport
@testable import PawnShopCore

/// Spell cards, card sets on sheets and plain backgrounds (R8.3.1, R8.7, R9).
@Suite struct SpellCardTests {
    private func longSpell() -> CatalogItem {
        var spell = catalogItem("Wall of Words", level: 4, kind: .spell)
        spell.traditions = ["arcane"]
        spell.stats = [ItemStat("Traditions", "arcane"), ItemStat("Cast", "◆◆")]
        spell.description = (1...14).map { "**Part \($0)** " + Array(repeating: "word", count: 30)
            .joined(separator: " ") }.joined(separator: "\n")
        return spell
    }

    @Test func spellKindsHaveTheirOwnLabelsAndLists() {
        #expect(ItemKind.spellKinds.map(\.cardLabel) == ["SPELL", "CANTRIP", "FOCUS", "RITUAL"])
        #expect(ItemKind.itemKinds.allSatisfy { $0.cardLabel == "ITEM" && !$0.isSpell })
        #expect(ItemKind.spellKinds.map(\.displayName) == ["Spells", "Cantrips", "Focus Spells", "Rituals"])
        #expect(Set(ItemKind.allCases) == Set(ItemKind.itemKinds + ItemKind.spellKinds))
    }

    @Test func filtersByTraditionAndReadsItemsWithoutTraditions() throws {
        var divine = catalogItem("Heal", level: 1, kind: .spell)
        divine.traditions = ["divine", "primal"]
        let catalog = ItemCatalog(items: [longSpell(), divine, catalogItem("Potion", level: 1)])
        #expect(catalog.search(ItemQuery(traditions: ["primal"])).map(\.name) == ["Heal"])
        #expect(catalog.search(ItemQuery(kinds: [.spell])).count == 2)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(divine)) as? [String: Any] ?? [:]
        json["traditions"] = nil
        let old = try JSONDecoder().decode(CatalogItem.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.traditions.isEmpty && old.name == "Heal")
    }

    @Test func printsEveryCardOfEachCopyTogether() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        let spell = longSpell()
        var sheet = PawnSheet()
        sheet.add(.item(spell.id), copies: 2)
        let renderer = PawnRenderer(library: library)
        renderer.generatedFolder = nil
        var exporter = SheetExporter(sheet: sheet, library: library, renderer: renderer)
        exporter.catalog = ItemCatalog(items: [spell])
        let cards = renderer.cardCount(for: spell)
        #expect(cards >= 2)
        #expect(exporter.layoutItems().first?.cardsPerCopy == cards)
        let placed = exporter.layout().pages.flatMap { $0 }
        #expect(placed.map { "\($0.copy).\($0.card)" }
            == (0..<2).flatMap { copy in (0..<cards).map { "\(copy).\($0)" } })
        let shown = exporter.contents(of: placed).compactMap { content -> Int? in
            if case .card(let card) = content { return card?.card }
            return nil
        }
        #expect(shown == placed.map(\.card))
        let pdf = try #require(PDFDocument(data: exporter.pdfData()))
        let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: " ")
        #expect(text.contains("SPELL 4") && text.contains("Card 1 of \(cards)") && text.contains("Card 2 of \(cards)"))
    }

    @Test func plainBackgroundsDropTheRexardPiecesButKeepTheIconFont() throws {
        var style = ItemCardStyle.pathfinder
        style.background = solidImage(red: 1, green: 0, blue: 0)
        style.titleBand = solidImage(red: 0, green: 1, blue: 0)
        let plain = style.withoutBackground
        #expect(plain.background == nil && plain.frame == nil && plain.titleBand == nil && plain.corners.isEmpty)
        let library = try PawnLibrary(folder: temporaryFolder())
        let renderer = PawnRenderer(library: library)
        let item = catalogItem("Potion", level: 1)
        #expect(renderer.printsCardBackgrounds)
        renderer.printsCardBackgrounds = false
        let image = try #require(renderer.cardImage(ItemCardContent(item: item, artwork: nil), height: 352))
        #expect(pixel(of: image, x: image.width / 2, y: image.height - 80).prefix(3) == [255, 255, 255])
    }

    @Test func aSmallerSmallestSizeLaysCardsOutAgain() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        let renderer = PawnRenderer(library: library)
        renderer.generatedFolder = nil
        let spell = longSpell()
        #expect(renderer.smallestCardTextSize == ItemCard.defaultSmallestTextSize)
        let roomy = renderer.cardPages(for: spell)
        renderer.smallestCardTextSize = 5.5
        let tight = renderer.cardPages(for: spell)
        #expect(tight.count <= roomy.count && tight.allSatisfy { $0.size >= 5.5 })
        #expect(renderer.cardPages[spell.id] == tight)
    }

    @Test func aCardOutsideTheSetDrawsTheLastOne() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        let renderer = PawnRenderer(library: library)
        renderer.generatedFolder = nil
        let spell = longSpell()
        let last = renderer.cardCount(for: spell) - 1
        let beyond = try #require(renderer.cardImage(ItemCardContent(item: spell, artwork: nil, card: 99), height: 200))
        let lastImage = try #require(renderer.cardImage(ItemCardContent(item: spell, artwork: nil, card: last),
                                                        height: 200))
        #expect(beyond.dataProvider?.data == lastImage.dataProvider?.data)
    }
}
