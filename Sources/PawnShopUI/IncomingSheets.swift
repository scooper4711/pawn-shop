#if os(macOS)
import AppKit
import PawnShopCore
import SwiftUI
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
            // It holds pawns nobody saved, so closing its window asks. Its window names it (`requestedTitle`).
            document.updateChangeCount(.changeDone)
        } catch {
            library.errorMessage = "Opening the sheet from the link failed: \(error.localizedDescription)"
        }
    }
}

extension View {
    /// Names an unsaved sheet after the title another app asked for (R13): its window shows the title and the save
    /// panel offers it as the file's name. A saved sheet shows its file's name, as any other does.
    func requestedTitle(_ title: String?) -> some View {
        background { if let title { DocumentNamer(name: title) } }
    }
}

/// Names the unsaved document of the window it sits in. The document is named from its window because one opened
/// as the app starts has no window yet when it is made, and a name set then never reaches the title bar.
private struct DocumentNamer: NSViewRepresentable {
    let name: String

    func makeNSView(context _: Context) -> NamingView { NamingView(name: name) }

    func updateNSView(_ view: NamingView, context _: Context) { view.name = name }

    final class NamingView: NSView {
        var name: String

        init(name: String) {
            self.name = name
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { fatalError("DocumentNamer's view is made in code") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // The window gets its document after its views: name it once both are there.
            DispatchQueue.main.async { [weak self] in self?.nameDocument() }
        }

        private func nameDocument() {
            guard let controller = window?.windowController, let document = controller.document as? NSDocument,
                  document.fileURL == nil else { return }
            document.displayName = name
            // In a window opened as the app starts, the title bar doesn't follow the document's name by itself.
            controller.synchronizeWindowTitleWithDocumentName()
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
