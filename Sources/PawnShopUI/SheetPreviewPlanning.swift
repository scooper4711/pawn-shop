import PawnShopCore
import SheetPreviewFile
import SwiftUI

extension View {
    /// Keeps the document's pictures of its pages ready to save with it (R12).
    func keepsSheetPreviews(of document: PawnSheetDocument) -> some View {
        modifier(SheetPreviewPlanner(document: document))
    }
}

/// Tells the document's keeper how its pages are drawn whenever they would look different, and draws them shortly
/// after an edit, so that saving rarely has to wait for them.
private struct SheetPreviewPlanner: ViewModifier {
    private static let settlingTime = Duration.seconds(1)

    let document: PawnSheetDocument
    @Environment(LibraryModel.self) private var library

    /// What the pictures depend on; `pageKeys` is nil when the device lacks some of the sheet's art.
    private struct Plan: Equatable {
        let keeper: ObjectIdentifier
        let sheet: PawnSheet
        let pageKeys: [String]?
    }

    func body(content: Content) -> some View {
        let pages = pagesToDraw()
        let plan = Plan(keeper: ObjectIdentifier(document.previewKeeper), sheet: document.sheet,
                        pageKeys: pages?.map(\.key))
        content
            .onChange(of: plan, initial: true) { document.previewKeeper.plan(pages?.map(\.page), for: plan.sheet) }
            .task(id: plan) {
                guard (try? await Task.sleep(for: Self.settlingTime)) != nil else { return }
                let keeper = document.previewKeeper
                _ = await Task.detached(priority: .utility) { keeper.previews(for: plan.sheet) }.value
            }
    }

    /// Each page's key and how to draw it; nil on a device lacking some of the sheet's art, which keeps the better
    /// pictures another device saved rather than drawing placeholders (R12.3).
    private func pagesToDraw() -> [(key: String, page: SheetPreviewKeeper.Page)]? {
        // Read so that the plan is made again when the library changes or pictures arrive from iCloud.
        _ = (library.pawns.count, library.itemArt.count)
        let sheet = document.sheet
        guard library.missingPictureCount(of: sheet) == 0, let renderer = library.backgroundRenderer,
              let exporter = library.exporter(for: sheet), exporter.hasEveryEntry else { return nil }
        return exporter.layout().pages.prefix(SheetPreviews.maximumPages).map { page in
            let drawing = PageDrawing(strips: page, contents: exporter.contents(of: page), settings: sheet.settings)
            let key = renderer.key(of: drawing)
            return (key, SheetPreviewKeeper.Page(key: key) { renderer.previewJPEG(of: drawing) })
        }
    }
}
