import PawnShopCore
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let pawnSheet = UTType(exportedAs: "com.github.scooper4711.pawnsheet", conformingTo: .json)
}

/// A `.pawnsheet` file: the pawns chosen for printing and how to print them.
struct PawnSheetDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pawnSheet]

    var sheet: PawnSheet

    init(sheet: PawnSheet = PawnSheet()) {
        self.sheet = sheet
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        sheet = try JSONDecoder().decode(PawnSheet.self, from: data)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(sheet))
    }
}
