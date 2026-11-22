import Foundation
import SheetPreviewFile

/// Keeps the pictures of a sheet's pages to save in its file (R12), and draws them when the sheet is saved.
///
/// It is a reference beside the document's value, not part of it: drawing pictures is not an edit, so it is never
/// undone and never marks a sheet as changed. The app says how the pages are drawn after each change (`plan`); the
/// thread saving the sheet asks for the pictures (`previews(for:)`), which draws the pages that changed.
public final class SheetPreviewKeeper: @unchecked Sendable {
    /// How to draw one page.
    public struct Page: Sendable {
        /// Changes whenever the page would look different.
        let key: String
        /// The page as a JPEG; empty when it can't be drawn.
        let draw: @Sendable () -> Data

        public init(key: String, draw: @escaping @Sendable () -> Data) {
            self.key = key
            self.draw = draw
        }
    }

    private struct Plan {
        let sheet: PawnSheet
        let pages: [Page]
    }

    /// Guards the properties below, briefly.
    private let state = NSLock()
    /// Held while pages are drawn, so that two savers never draw the same pages.
    private let drawing = NSLock()
    /// The pictures last read from the file or drawn.
    private var kept: SheetPreviews
    private var plan: Plan?
    /// The pictures drawn for the plan's pages, by their keys.
    private var drawn: [String: Data] = [:]

    public init(previews: SheetPreviews = SheetPreviews()) {
        kept = previews
    }

    /// Says how `sheet`'s pages are drawn. Without pages, as on a device lacking some of the sheet's art, the
    /// pictures already kept are saved with it instead (R12.3).
    public func plan(_ pages: [Page]?, for sheet: PawnSheet) {
        state.withLock {
            plan = pages.map { Plan(sheet: sheet, pages: Array($0.prefix(SheetPreviews.maximumPages))) }
        }
    }

    /// The pictures to save with `sheet`, drawing the pages that changed since they were last drawn. A sheet other
    /// than the one planned, or a page that can't be drawn, gets the pictures already kept.
    public func previews(for sheet: PawnSheet) -> SheetPreviews {
        drawing.withLock {
            guard let pages = plannedPages(for: sheet) else { return state.withLock { kept } }
            var pictures: [(key: String, data: Data)] = []
            for page in pages {
                // An edit made meanwhile has its own save coming, which draws its pages.
                guard plannedPages(for: sheet) != nil else { return state.withLock { kept } }
                let data = state.withLock { drawn[page.key] } ?? page.draw()
                guard !data.isEmpty else { return state.withLock { kept } }
                pictures.append((page.key, data))
            }
            return keep(pictures)
        }
    }

    private func plannedPages(for sheet: PawnSheet) -> [Page]? {
        state.withLock { plan?.sheet == sheet ? plan?.pages : nil }
    }

    private func keep(_ pictures: [(key: String, data: Data)]) -> SheetPreviews {
        state.withLock {
            drawn = Dictionary(pictures.map { ($0.key, $0.data) }) { first, _ in first }
            kept = SheetPreviews(pages: pictures.map(\.data))
            return kept
        }
    }
}

extension SheetExporter {
    /// Whether the device has every pawn and item the sheet prints, so that none is drawn as a placeholder. An
    /// item's card without art from an item deck counts: that is how the card prints on this device.
    public var hasEveryEntry: Bool {
        sheet.entries.allSatisfy { entry in
            switch entry.content {
            case .pawn(let pawnID): library.pawn(id: pawnID) != nil
            case .item(let itemID): catalog.item(id: itemID) != nil
            }
        }
    }
}
