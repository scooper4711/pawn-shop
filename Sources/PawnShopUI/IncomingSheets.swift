#if os(macOS)
import AppKit
import PawnShopCore
import TablesideShared

/// Opens the sheets other Tableside Toolkit apps ask for with a `pawnshop://sheet` link (R13). SwiftUI can't open
/// a new document with given contents from outside a view, so a sheet is parked here and an untitled document is
/// asked for: the document group's `newDocument` closure takes what is parked.
@MainActor
enum IncomingSheets {
    private nonisolated static let parked = ParkedSheet()

    /// Opens the sheet a link asks for in a new, unsaved document named after the request's title.
    static func open(_ url: URL, library: LibraryModel = .shared) {
        let request: PawnSheetRequest
        do {
            request = try PawnSheetRequest(url: url)
        } catch .unrecognizedLink {
            return
        } catch {
            library.errorMessage = error.localizedDescription
            return
        }
        let sheet = PawnSheet(request: request) { library.pawn(id: $0) }
        open(PawnSheetDocument(sheet: sheet, requestedTitle: request.title.isEmpty ? nil : request.title),
             library: library)
    }

    /// The document being opened for a link, or an empty one when a document is opened any other way.
    nonisolated static func newDocument() -> PawnSheetDocument {
        parked.take() ?? PawnSheetDocument()
    }

    private static func open(_ sheet: PawnSheetDocument, library: LibraryModel) {
        parked.put(sheet)
        // Whatever happens, the sheet isn't left for the next File › New.
        defer { _ = parked.take() }
        do {
            let document = try NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
            // The save panel offers the title as the file's name; the window shows it (`SheetWindow`).
            if let title = sheet.requestedTitle { document.displayName = title }
            // It holds pawns nobody saved, so closing its window asks.
            document.updateChangeCount(.changeDone)
        } catch {
            library.errorMessage = "Opening the sheet from the link failed: \(error.localizedDescription)"
        }
    }
}

/// A sheet handed from the link to the document being made for it, which may be built off the main thread.
private final class ParkedSheet: @unchecked Sendable {
    private let lock = NSLock()
    private var sheet: PawnSheetDocument?

    func put(_ sheet: PawnSheetDocument) {
        lock.withLock { self.sheet = sheet }
    }

    func take() -> PawnSheetDocument? {
        lock.withLock {
            defer { sheet = nil }
            return sheet
        }
    }
}
#endif
