import PawnShopCore
import SheetPreviewFile
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let pawnSheet = UTType(exportedAs: "io.github.scooper4711.pawnsheet", conformingTo: .data)
}

/// A `.pawnsheet` file: the pawns chosen for printing, how to print them, and small pictures of the pages (R12).
struct PawnSheetDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pawnSheet]

    var sheet: PawnSheet
    /// The pictures of the pages. A reference beside the document's value: drawing them is not an edit, so it is
    /// never undone and never marks the sheet as changed.
    let previewKeeper: SheetPreviewKeeper
    /// What to call the sheet until it is saved, when another app asked for it (R13); never saved.
    var requestedTitle: String?

    init(sheet: PawnSheet = PawnSheet(), requestedTitle: String? = nil) {
        self.sheet = sheet
        self.requestedTitle = requestedTitle
        previewKeeper = SheetPreviewKeeper()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let file = try SheetFile(data: data)
        sheet = file.sheet
        previewKeeper = SheetPreviewKeeper(previews: file.previews)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        // The pictures are drawn here, on the thread saving the sheet, so they always match what is saved.
        let file = SheetFile(sheet: sheet, previews: previewKeeper.previews(for: sheet))
        return FileWrapper(regularFileWithContents: try file.data())
    }
}
