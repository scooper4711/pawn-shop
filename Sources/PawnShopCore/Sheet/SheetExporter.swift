import CoreGraphics
import ArtExtraction
import Foundation

/// Turns a sheet into pages: the layout for previews, and PDF data for export and printing.
public struct SheetExporter {
    /// What a missing pawn takes up on the page: a medium strip.
    static let placeholderSize = PawnSize.medium.outlineSize

    public let sheet: PawnSheet
    public let library: PawnLibrary
    public let renderer: PawnRenderer
    /// The items whose cards the sheet prints.
    public var catalog = ItemCatalog(items: [])

    public init(sheet: PawnSheet, library: PawnLibrary, renderer: PawnRenderer) {
        self.sheet = sheet
        self.library = library
        self.renderer = renderer
    }

    /// One layout item per entry: a pawn's strip, sized from its outline and the room left for a base, or a card.
    public func layoutItems() -> [LayoutItem] {
        sheet.entries.map { entry in
            guard case .pawn(let pawnID) = entry.content else {
                return LayoutItem(entryID: entry.id, stripSize: ItemCard.size, count: entry.count)
            }
            let upright = library.pawn(id: pawnID).map(renderer.uprightSize(of:)) ?? Self.placeholderSize
            let strip = LayoutItem.stripSize(forPawn: upright, footRoom: sheet.settings.footRoom)
            return LayoutItem(entryID: entry.id, stripSize: strip, count: entry.count)
        }
    }

    public func layout() -> SheetLayout {
        SheetLayout.arrange(layoutItems(), settings: sheet.settings)
    }

    /// A PDF of the sheet at 100% scale, one page per layout page, on the sheet's paper.
    public func pdfData() -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: sheet.settings.paper.paperSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return Data() }
        for page in layout().pages {
            context.beginPDFPage(nil)
            drawPage(page, in: context)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    /// Draws one layout page's strips and cards into `context`, in page coordinates.
    public func drawPage(_ page: [PlacedStrip], in context: CGContext) {
        for (placed, content) in zip(page, contents(of: page)) {
            renderer.draw(content, in: placed, settings: sheet.settings, context: context)
        }
    }

    /// What each strip of a page shows, ready to draw on another thread.
    public func contents(of page: [PlacedStrip]) -> [PlacedContent] {
        let contents = Dictionary(uniqueKeysWithValues: sheet.entries.map { ($0.id, $0.content) })
        let matcher = library.itemArtMatcher
        return page.map { placed in
            switch contents[placed.entryID] {
            case .item(let itemID):
                .card(catalog.item(id: itemID).map { ItemCardContent(item: $0, artwork: matcher.artwork(for: $0)) })
            case .pawn(let pawnID):
                .pawn(library.pawn(id: pawnID))
            case nil:
                .pawn(nil)
            }
        }
    }
}
