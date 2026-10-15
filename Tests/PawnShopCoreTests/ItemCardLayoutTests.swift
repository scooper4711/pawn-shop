import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// Splitting long text over cards (R8.3.1).
@Suite struct ItemCardLayoutTests {
    private func spell(_ description: String, stats: [ItemStat] = []) -> CatalogItem {
        var spell = CatalogItem(id: "pathfinder/s", game: .pathfinder, name: "Test Spell", level: 2, kind: .spell)
        spell.traits = ["Acid", "Concentrate"]
        spell.stats = stats
        spell.description = description
        return spell
    }

    private func words(_ count: Int, _ word: String = "word") -> String {
        Array(repeating: word, count: count).joined(separator: " ")
    }

    @Test func shortTextFitsOneCardAtTheStandardSize() {
        let cards = ItemCardLayout.cards(for: spell("A roaring blast of fire."), actionFont: nil)
        #expect(cards == [ItemCardPage(markup: "A roaring blast of fire.", size: ItemCardLayout.standardSize)])
    }

    @Test func textThatNearlyFitsIsSetSlightlySmaller() throws {
        let item = spell("")
        let pager = CardPager(first: ItemCardGeometry(item: item).textRect(isFirstCard: true),
                              next: ItemCardGeometry(item: item).textRect(isFirstCard: false), actionFont: nil)
        // The most words that fit a little smaller, which can't all fit at the standard size.
        let smaller = ItemCardLayout.smallerSizes(downTo: 6.25)[1]
        let count = try #require((1...1000).last { pager.fits([words($0)], isFirstCard: true, size: smaller) })
        #expect(count < 1000)
        #expect(!pager.fits([words(count)], isFirstCard: true, size: ItemCardLayout.standardSize))
        let cards = ItemCardLayout.cards(for: spell(words(count)), actionFont: nil)
        #expect(cards.count == 1 && cards[0].size < ItemCardLayout.standardSize
            && cards[0].size >= ItemCardLayout.defaultSmallestSize)
    }

    @Test func shrinksQuarterPointsDownToTheChosenSmallestSize() {
        #expect(ItemCardLayout.smallerSizes(downTo: 6.25) == [6.75, 6.5, 6.25])
        #expect(ItemCardLayout.smallerSizes(downTo: 5.5).last == 5.5)
        #expect(ItemCardLayout.smallerSizes(downTo: 2).last == 5.5)
        #expect(ItemCardLayout.smallerSizes(downTo: 9).isEmpty)
        let text = (1...12).map { "**Part \($0)** " + words(30) }.joined(separator: "\n")
        let roomy = ItemCardLayout.cards(for: spell(text), actionFont: nil, smallestSize: 6.5)
        let tight = ItemCardLayout.cards(for: spell(text), actionFont: nil, smallestSize: 5.5)
        #expect(tight.count <= roomy.count && tight.allSatisfy { $0.size >= 5.5 })
    }

    @Test func longTextContinuesOnMoreCardsAndKeepsEveryWord() {
        let paragraphs = (1...12).map { "**Part \($0)** " + words(30) }
        let cards = ItemCardLayout.cards(for: spell(paragraphs.joined(separator: "\n")), actionFont: nil)
        #expect(cards.count >= 2)
        #expect(Set(cards.map(\.size)).count == 1)
        let joined = cards.map(\.markup).joined(separator: " ")
        #expect(joined.components(separatedBy: "word").count - 1 == 12 * 30)
        #expect((1...12).allSatisfy { joined.contains("**Part \($0)**") })
    }

    @Test func aHeightenedEntryMovesWholeAndRulesDropAtABreak() {
        let body = (1...9).map { "**Part \($0)** " + words(28) }.joined(separator: "\n")
        let cards = ItemCardLayout.cards(for: spell(body + "\n---\n**Heightened (+2)** " + words(25)),
                                         actionFont: nil)
        let heightened = cards.filter { $0.markup.contains("Heightened") }
        #expect(heightened.count == 1)
        #expect(heightened[0].markup.contains("**Heightened (+2)** " + words(25)))
        #expect(cards.allSatisfy { !$0.markup.hasPrefix("---") && !$0.markup.hasSuffix("---") })
    }

    @Test func aParagraphLongerThanACardIsSplitBetweenWordsKeepingItsEmphasis() {
        let long = "**Effect " + words(400) + "**"
        let cards = ItemCardLayout.cards(for: spell(long), actionFont: nil)
        #expect(cards.count >= 2)
        #expect(cards.allSatisfy { $0.markup.hasPrefix("**") && $0.markup.hasSuffix("**") })
    }

    @Test func splitsCloseAndReopenEmphasis() {
        let split = MarkupSplit(words: ["**Heightened", "(+2)**", "*more*", "*and", "more*"], count: 4)
        #expect(split.head == "**Heightened (+2)** *more* *and*")
        #expect(split.tail == "*more*")
        let bold = MarkupSplit(words: ["**One", "two**"], count: 1)
        #expect(bold.head == "**One**" && bold.tail == "**two**")
    }

    @Test func aSpellsStatsSitUnderItsTraitsAndAnItemsAboveTheSource() {
        let stats = [ItemStat("Traditions", "arcane, primal"), ItemStat("Range", "120 feet")]
        let spellGeometry = ItemCardGeometry(item: spell("", stats: stats))
        #expect(spellGeometry.statsRect.maxY < spellGeometry.chipsBottom)
        #expect(spellGeometry.textRect(isFirstCard: true).maxY < spellGeometry.statsRect.minY)
        var item = spell("", stats: stats)
        item.kind = .consumable
        let itemGeometry = ItemCardGeometry(item: item)
        #expect(itemGeometry.statsRect.minY > itemGeometry.source.maxY)
        #expect(itemGeometry.textRect(isFirstCard: true).minY > itemGeometry.statsRect.maxY)
        #expect(itemGeometry.textRect(isFirstCard: false).height > itemGeometry.textRect(isFirstCard: true).height)
    }
}
