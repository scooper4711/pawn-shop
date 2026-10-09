import CoreGraphics
import Foundation

/// Turns a sheet into pages: the layout for previews, and PDF data for export and printing.
public struct SheetExporter {
    /// What a missing pawn takes up on the page: a medium strip.
    static let placeholderSize = PawnSize.medium.outlineSize

    public let sheet: PawnSheet
    public let library: PawnLibrary
    public let renderer: PawnRenderer

    public init(sheet: PawnSheet, library: PawnLibrary, renderer: PawnRenderer) {
        self.sheet = sheet
        self.library = library
        self.renderer = renderer
    }

    /// One layout item per entry, sized from the pawn's outline and the room left for a base.
    public func layoutItems() -> [LayoutItem] {
        sheet.entries.map { entry in
            let upright = library.pawn(id: entry.pawnID).map(renderer.uprightSize(of:)) ?? Self.placeholderSize
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

    /// Draws one layout page's strips into `context`, in page coordinates.
    public func drawPage(_ page: [PlacedStrip], in context: CGContext) {
        let pawnIDs = Dictionary(uniqueKeysWithValues: sheet.entries.map { ($0.id, $0.pawnID) })
        for placed in page {
            let pawn = pawnIDs[placed.entryID].flatMap(library.pawn(id:))
            renderer.drawStrip(pawn, in: placed, settings: sheet.settings, context: context)
        }
    }
}
