import Foundation
import SheetPreviewFile

/// What a `.pawnsheet` file holds: the sheet, and the small pictures of its pages (R12).
public struct SheetFile: Encodable, Equatable, Sendable {
    public var sheet: PawnSheet
    public var previews: SheetPreviews

    public init(sheet: PawnSheet, previews: SheetPreviews = SheetPreviews()) {
        self.sheet = sheet
        self.previews = previews
    }

    /// Reads a file. Pictures that can't be read never stop the sheet from opening.
    public init(data: Data) throws {
        sheet = try JSONDecoder().decode(PawnSheet.self, from: data)
        previews = SheetPreviews(fileData: data)
    }

    public func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// The sheet's keys and the pictures' key, side by side at the top of the file.
    public func encode(to encoder: Encoder) throws {
        try sheet.encode(to: encoder)
        try previews.encode(to: encoder)
    }
}
