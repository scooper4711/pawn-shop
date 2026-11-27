import ArtExtraction
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
    /// The newest format this app opens (R12.6): 2, in which a sheet another app made may leave its settings out.
    /// Raise it only for a change an older app would get wrong: one that only adds keys, which older apps ignore,
    /// keeps the number.
    public static let currentFormatVersion = 2
    /// The format this app saves: 1, because a sheet it saves holds its settings, so apps that only know format 1
    /// keep opening it.
    public static let savedFormatVersion = 1
    /// What the sheet's list says when the file comes from a newer reader and some of its pawns aren't found.
    public static let newerReaderNotice =
        "This sheet was made with a newer version of Pawn Shop. Update Pawn Shop to see the pawns missing here."

    public var sheet: PawnSheet
    public var previews: SheetPreviews
    /// False for a file that leaves the sheet's settings to this app, as one made by another app does.
    public var hasSettings = true
    /// The version of the PDF reader behind the library of whoever wrote the file; nil when the file doesn't say.
    public var readerVersion: Int? = PawnExtractor.version

    public init(sheet: PawnSheet, previews: SheetPreviews = SheetPreviews()) {
        self.sheet = sheet
        self.previews = previews
    }

    /// Reads a file, its format first: a newer one is refused before the rest, which may have changed, is read.
    /// Pictures that can't be read never stop the sheet from opening.
    public init(data: Data) throws {
        let header = try JSONDecoder().decode(SheetFileHeader.self, from: data)
        let format = header.formatVersion ?? 1
        guard format <= Self.currentFormatVersion else { throw SheetFileError.newerFormat(format) }
        sheet = try JSONDecoder().decode(PawnSheet.self, from: data)
        previews = SheetPreviews(fileData: data)
        hasSettings = header.hasSettings
        readerVersion = header.readerVersion
    }

    /// True when a newer reader than this app's made the pawns' IDs, so this app may not find some of them.
    public var isFromNewerReader: Bool {
        readerVersion.map { $0 > PawnExtractor.version } ?? false
    }

    public func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// The format, the reader's version, the sheet's keys and the pictures' key, side by side at the top of the
    /// file.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SheetFileHeader.CodingKeys.self)
        try container.encode(Self.savedFormatVersion, forKey: .formatVersion)
        try container.encodeIfPresent(readerVersion, forKey: .readerVersion)
        try sheet.encode(to: encoder)
        try previews.encode(to: encoder)
    }
}

/// What is read before the sheet: the file's format (none in a file saved before formats were numbered, which
/// is format 1), the reader's version, and whether the sheet brings its settings.
private struct SheetFileHeader: Decodable {
    var formatVersion: Int?
    var readerVersion: Int?
    var hasSettings: Bool

    enum CodingKeys: String, CodingKey { case formatVersion, readerVersion, settings }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion)
        readerVersion = try container.decodeIfPresent(Int.self, forKey: .readerVersion)
        hasSettings = container.contains(.settings)
    }
}
