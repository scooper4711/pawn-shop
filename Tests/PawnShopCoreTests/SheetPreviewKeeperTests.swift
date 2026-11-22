import ArtExtractionTestSupport
import Foundation
import SheetPreviewFile
import Testing
@testable import PawnShopCore

@Suite struct SheetPreviewKeeperTests {
    private let sheet = PawnSheet(entries: [SheetEntry(pawnID: UUID(), count: 2)])
    private let loaded = SheetPreviews(pages: [Data([9])])

    @Test func drawsThePlannedPagesWhenAsked() {
        let keeper = SheetPreviewKeeper(previews: loaded)
        keeper.plan([page("a", Data([1])), page("b", Data([2]))], for: sheet)
        #expect(keeper.previews(for: sheet).pages == [Data([1]), Data([2])])
    }

    @Test func drawsOnlyThePagesThatChanged() {
        let counter = Counter()
        let keeper = SheetPreviewKeeper()
        keeper.plan([page("a", Data([1]), counting: counter), page("b", Data([2]), counting: counter)], for: sheet)
        _ = keeper.previews(for: sheet)
        var edited = sheet
        edited.add(UUID())
        keeper.plan([page("a", Data([1]), counting: counter), page("c", Data([3]), counting: counter)], for: edited)
        #expect(keeper.previews(for: edited).pages == [Data([1]), Data([3])])
        #expect(counter.count == 3)
    }

    @Test func keepsTheFilesPicturesWithoutAPlan() {
        #expect(SheetPreviewKeeper(previews: loaded).previews(for: sheet) == loaded)
    }

    @Test func keepsThePicturesOnADeviceLackingArt() {
        let keeper = SheetPreviewKeeper(previews: loaded)
        keeper.plan([page("a", Data([1]))], for: sheet)
        _ = keeper.previews(for: sheet)
        keeper.plan(nil, for: sheet)
        #expect(keeper.previews(for: sheet).pages == [Data([1])])
    }

    @Test func keepsThePicturesForASheetOtherThanThePlanned() {
        let keeper = SheetPreviewKeeper(previews: loaded)
        keeper.plan([page("a", Data([1]))], for: sheet)
        #expect(keeper.previews(for: PawnSheet()) == loaded)
    }

    @Test func keepsThePicturesWhenAPageCannotBeDrawn() {
        let keeper = SheetPreviewKeeper(previews: loaded)
        keeper.plan([page("a", Data([1])), page("b", Data())], for: sheet)
        #expect(keeper.previews(for: sheet) == loaded)
    }

    @Test func stopsDrawingWhenTheSheetChangesMeanwhile() {
        let keeper = SheetPreviewKeeper(previews: loaded)
        let counter = Counter()
        let first = SheetPreviewKeeper.Page(key: "a") {
            keeper.plan([], for: PawnSheet())
            return Data([1])
        }
        keeper.plan([first, page("b", Data([2]), counting: counter)], for: sheet)
        #expect(keeper.previews(for: sheet) == loaded && !counter.wasUsed)
    }

    @Test func anEmptySheetHasNoPictures() {
        let keeper = SheetPreviewKeeper(previews: loaded)
        keeper.plan([], for: PawnSheet())
        #expect(keeper.previews(for: PawnSheet()).pages.isEmpty)
    }

    @Test func drawsAtMostTheMaximumPages() {
        let keeper = SheetPreviewKeeper()
        keeper.plan((0..<SheetPreviews.maximumPages + 3).map { page("\($0)", Data([1])) }, for: sheet)
        #expect(keeper.previews(for: sheet).pages.count == SheetPreviews.maximumPages)
    }

    @Test func aSheetHasEveryEntryOnlyWithItsPawnsAndItems() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        let potion = catalogItem("Healing Potion (Minor)", level: 1)
        var sheet = PawnSheet()
        sheet.add(.item(potion.id))
        var exporter = SheetExporter(sheet: sheet, library: library, renderer: PawnRenderer(library: library))
        #expect(!exporter.hasEveryEntry)
        exporter.catalog = ItemCatalog(items: [potion])
        #expect(exporter.hasEveryEntry)
        sheet.add(UUID())
        var lackingAPawn = SheetExporter(sheet: sheet, library: library, renderer: PawnRenderer(library: library))
        lackingAPawn.catalog = exporter.catalog
        #expect(!lackingAPawn.hasEveryEntry)
    }

    private func page(_ key: String, _ data: Data, counting counter: Counter? = nil) -> SheetPreviewKeeper.Page {
        SheetPreviewKeeper.Page(key: key) {
            counter?.add()
            return data
        }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int { lock.withLock { value } }
    var wasUsed: Bool { lock.withLock { value != 0 } }

    func add() { lock.withLock { value += 1 } }
}
