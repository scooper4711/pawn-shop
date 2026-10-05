import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

@Suite struct PawnSheetTests {
    let goblin = UUID(), ogre = UUID()

    @Test func addsCopiesToOneEntryPerPawn() {
        var sheet = PawnSheet()
        sheet.add(goblin, copies: 2)
        sheet.add(ogre)
        sheet.add(goblin)
        sheet.add(ogre, copies: 0)
        #expect(sheet.entries.map(\.count) == [3, 1])
        #expect(sheet.copyCount == 4)
    }

    @Test func changesAndRemovesCopies() throws {
        var sheet = PawnSheet()
        sheet.add(goblin, copies: 2)
        sheet.add(ogre)
        let goblinEntry = try #require(sheet.entries.first).id
        let ogreEntry = sheet.entries[1].id
        sheet.removeCopy(of: goblinEntry)
        #expect(sheet.entries.first?.count == 1)
        sheet.removeCopy(of: goblinEntry)
        #expect(sheet.entries.map(\.id) == [ogreEntry])
        sheet.setCount(5, of: ogreEntry)
        #expect(sheet.copyCount == 5)
        sheet.setCount(0, of: ogreEntry)
        #expect(sheet.entries.isEmpty)
        sheet.add(goblin)
        sheet.remove(sheet.entries[0].id)
        sheet.removeCopy(of: UUID())
        #expect(sheet.entries.isEmpty)
    }

    @Test func savesAndReadsBack() throws {
        var sheet = PawnSheet(settings: SheetSettings(cutStyle: .gaps(9), showsFoldLine: false))
        sheet.add(goblin, copies: 3)
        let decoded = try JSONDecoder().decode(PawnSheet.self, from: JSONEncoder().encode(sheet))
        #expect(decoded == sheet)
    }
}

@Suite struct SheetLayoutTests {
    let medium = LayoutItem.stripSize(forPawn: PawnSize.medium.outlineSize)
    let huge = LayoutItem.stripSize(forPawn: PawnSize.huge.outlineSize)

    @Test func fillsRowsFromTheTopLeft() throws {
        let layout = SheetLayout.arrange([LayoutItem(entryID: UUID(), stripSize: huge, count: 2)],
                                         settings: SheetSettings())
        let page = try #require(layout.pages.first)
        #expect(layout.pages.count == 1)
        #expect(page.map(\.copy) == [0, 1])
        #expect(page.first?.rect == CGRect(x: 18, y: 774 - huge.height, width: huge.width, height: huge.height))
        #expect(page.last?.rect.minX == 18 + huge.width)
    }

    @Test func startsANewPageWhenOneIsFull() {
        let layout = SheetLayout.arrange([LayoutItem(entryID: UUID(), stripSize: huge, count: 4)],
                                         settings: SheetSettings())
        #expect(layout.pages.map(\.count) == [2, 2])
    }

    @Test func turnsAStripThatOnlyFitsOneWay() {
        let gargantuan = LayoutItem.stripSize(forPawn: PawnSize.gargantuan.outlineSize)
        let layout = SheetLayout.arrange([LayoutItem(entryID: UUID(), stripSize: medium, count: 18),
                                          LayoutItem(entryID: UUID(), stripSize: gargantuan, count: 1)],
                                         settings: SheetSettings())
        let strips = layout.pages.flatMap { $0 }
        #expect(strips.contains { !$0.sideways && $0.rect.size == gargantuan })
    }

    @Test func turnsStripsSidewaysWhenThatSavesPages() {
        // Upright, Letter holds 14 medium strips; sideways it holds 18.
        let item = LayoutItem(entryID: UUID(), stripSize: medium, count: 18)
        let layout = SheetLayout.arrange([item], settings: SheetSettings())
        #expect(layout.pages.count == 1)
        #expect(layout.pages[0].allSatisfy { $0.sideways && $0.rect.width == medium.height })
        let few = SheetLayout.arrange([LayoutItem(entryID: UUID(), stripSize: medium, count: 3)],
                                      settings: SheetSettings())
        #expect(few.pages[0].allSatisfy { !$0.sideways })
    }

    @Test func leavesGapsBetweenStrips() {
        let layout = SheetLayout.arrange([LayoutItem(entryID: UUID(), stripSize: medium, count: 2)],
                                         settings: SheetSettings(cutStyle: .gaps(10)))
        let rects = layout.pages[0].map(\.rect)
        #expect(rects[1].minX - rects[0].maxX == 10)
        #expect(CutStyle.gaps(-3).spacing == 0)
    }

    @Test func placesTallerStripsFirst() {
        let small = UUID(), big = UUID()
        let layout = SheetLayout.arrange([LayoutItem(entryID: small, stripSize: medium, count: 1),
                                          LayoutItem(entryID: big, stripSize: huge, count: 1)],
                                         settings: SheetSettings())
        #expect(layout.pages[0].map(\.entryID) == [big, small])
    }

    @Test func findsTheStripAtAPoint() {
        let entry = UUID()
        let layout = SheetLayout.arrange([LayoutItem(entryID: entry, stripSize: medium, count: 1)],
                                         settings: SheetSettings())
        let rect = layout.pages[0][0].rect
        #expect(layout.strip(at: CGPoint(x: rect.midX, y: rect.midY), onPage: 0)?.entryID == entry)
        #expect(layout.strip(at: CGPoint(x: 1, y: 1), onPage: 0) == nil)
        #expect(layout.strip(at: CGPoint(x: rect.midX, y: rect.midY), onPage: 3) == nil)
    }

    @Test func keepsEveryStripInsideThePrintableAreaWithoutOverlaps() {
        var random = SeededRandom(seed: 42)
        let sizes = PawnSize.allCases.map { LayoutItem.stripSize(forPawn: $0.outlineSize) }
        for _ in 0..<200 {
            let items = (0..<Int.random(in: 1...6, using: &random)).map { _ in
                LayoutItem(entryID: UUID(), stripSize: sizes.randomElement(using: &random)!,
                           count: Int.random(in: 0...12, using: &random))
            }
            let gap = Bool.random(using: &random) ? CutStyle.sharedLines
                                                  : .gaps(CGFloat.random(in: 0...20, using: &random))
            let settings = SheetSettings(cutStyle: gap)
            let layout = SheetLayout.arrange(items, settings: settings)
            let strips = layout.pages.flatMap { $0 }
            #expect(strips.count == items.reduce(0) { $0 + $1.count })
            for page in layout.pages {
                #expect(!page.isEmpty)
                for (index, strip) in page.enumerated() {
                    #expect(settings.paper.imageableRect.insetBy(dx: -0.001, dy: -0.001).contains(strip.rect))
                    for other in page[(index + 1)...] {
                        let overlap = strip.rect.intersection(other.rect)
                        #expect(overlap.isNull || overlap.width * overlap.height < 0.001)
                    }
                }
            }
        }
    }
}

/// A repeatable random number generator (SplitMix64), so property tests fail the same way every run.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
