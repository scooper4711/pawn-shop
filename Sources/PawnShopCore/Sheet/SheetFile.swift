import Foundation
import SheetPreviewFile

/// Why a `.pawnsheet` file couldn't be opened.
public enum SheetFileError: Error, Equatable, LocalizedError {
    /// The file is in a newer format than this app knows (R12.6).
    case newerFormat(Int)

    public var errorDescription: String? {
        switch self {
        case .newerFormat(let version):
            "Opening the sheet failed: it was made by a newer version of Pawn Shop (sheet format \(version)). "
                + "Update Pawn Shop to open it."
        }
    }
}

/// What a `.pawnsheet` file holds: its format, the sheet, and the small pictures of its pages (R12).
public struct SheetFile: Encodable, Equatable, Sendable {
    /// The newest format this app opens and the one it saves (R12.6). Raise it only for a change an older app would
    /// get wrong: one that only adds keys, which older apps ignore, keeps the number.
    public static let currentFormatVersion = 1

    public var sheet: PawnSheet
    public var previews: SheetPreviews

    public init(sheet: PawnSheet, previews: SheetPreviews = SheetPreviews()) {
        self.sheet = sheet
        self.previews = previews
    }

    /// Reads a file, its format first: a newer one is refused before the rest, which may have changed, is read.
    /// Pictures that can't be read never stop the sheet from opening.
    public init(data: Data) throws {
        let format = try JSONDecoder().decode(Format.self, from: data).formatVersion ?? 1
        guard format <= Self.currentFormatVersion else { throw SheetFileError.newerFormat(format) }
        sheet = try JSONDecoder().decode(PawnSheet.self, from: data)
        previews = SheetPreviews(fileData: data)
    }

    public func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// The format, the sheet's keys and the pictures' key, side by side at the top of the file.
    public func encode(to encoder: Encoder) throws {
        try Format(formatVersion: Self.currentFormatVersion).encode(to: encoder)
        try sheet.encode(to: encoder)
        try previews.encode(to: encoder)
    }

    /// The file's format. A file saved before formats were numbered has none and is in format 1.
    private struct Format: Codable {
        var formatVersion: Int?
    }
}
