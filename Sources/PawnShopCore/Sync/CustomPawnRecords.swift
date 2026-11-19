import ArtExtraction
import CoreGraphics
import CryptoKit
import Foundation

/// What a custom pawn's record holds, as JSON with sorted keys (R10.2). Fields are only ever added, as optionals,
/// and a missing one keeps the value here. A digest is always taken of the payload as this version encodes it,
/// never of the bytes that arrived, or two versions of the app would send their records over each other forever
/// (tabletop-kit library sync design). The image's file name isn't here: each device names the file itself.
struct CustomPawnPayload: Codable, Equatable {
    var id: UUID
    var name: String
    var size: PawnSize
    /// Where the image sits (`CustomArt.focus`).
    var focusX: Double
    var focusY: Double
    var showsName: Bool
    var scaling: ArtScaling
    var tags: [String]
    var tagModel: String
    var tagsCorrected: Bool
    /// The user's last change, in seconds since the reference date; 0 for a pawn made before changes were timed.
    var modified: Double

    /// The payload of a custom pawn; nil for a pawn read from a PDF.
    init?(_ pawn: Pawn, modified: Double) {
        guard case .custom(let art) = pawn.art else { return nil }
        id = pawn.id
        name = pawn.name
        size = pawn.size
        focusX = Double(art.focus.x)
        focusY = Double(art.focus.y)
        showsName = art.showsName
        scaling = art.scaling
        tags = pawn.tags
        tagModel = pawn.tagModel
        tagsCorrected = pawn.tagsCorrected
        self.modified = modified
    }

    /// The payload in `data`; nil when this version can't read it.
    init?(data: Data) {
        guard let payload = try? JSONDecoder().decode(CustomPawnPayload.self, from: data) else { return nil }
        self = payload
    }

    /// The canonical JSON: keys sorted, so a digest means the same on every device.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    /// The pawn the payload describes, drawn from the image in `imageFile` of the custom art folder.
    func pawn(imageFile: String) -> Pawn {
        let art = CustomArt(imageFile: imageFile, focus: CGPoint(x: focusX, y: focusY), showsName: showsName,
                            scaling: scaling)
        var pawn = Pawn(id: id, name: name, size: size, art: .custom(art))
        pawn.tags = tags
        pawn.tagModel = tagModel
        pawn.tagsCorrected = tagsCorrected
        return pawn
    }

    /// The SHA-256 of a payload's bytes, in hexadecimal.
    static func digest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// A custom pawn's record as another device saved it.
struct RemoteCustomPawn {
    var id: UUID
    /// The payload's bytes; empty when the record is in a layout this version can't read.
    var payload: Data
    /// The image's file, for as long as the event that brought it lasts; nil for the server's copy of a save it
    /// refused, which comes without its files.
    var image: URL?
    /// The record's archived system fields: its change tag, so the next save of it is no conflict.
    var systemFields: Data
}

/// What another device did to a custom pawn's record.
enum CustomPawnChange {
    case saved(RemoteCustomPawn)
    case deleted(UUID)
}

/// A custom pawn's record to save.
struct OutgoingCustomPawn: Equatable {
    var id: UUID
    var payload: Data
    /// The payload's digest when the record was built, so a change made while it is on its way still counts.
    var digest: String
    /// The pawn's name, for people reading the CloudKit Console.
    var title: String
    var image: URL
    /// The server's last known copy, when it has one.
    var systemFields: Data?
}

/// The custom pawns' records to save and to delete.
struct CustomPawnCandidates: Equatable {
    var saves: [UUID] = []
    var deletions: [UUID] = []

    var isEmpty: Bool { saves.isEmpty && deletions.isEmpty }
}

/// What this device knows the server holds of the custom pawns (`pawn-shop-sync.json`), as the shared library's
/// `cloudRecords` is for its own records. Without it, or with a file that can't be read, every pawn is sent again
/// and merged with what is there.
struct CustomPawnLedger: Codable, Equatable {
    static let fileName = "pawn-shop-sync.json"

    struct Entry: Codable, Equatable {
        /// The record's archived system fields; nil once the server is known not to hold the record.
        var systemFields: Data?
        /// The digest of the payload the server holds.
        var digest: String
        /// True when the server's copy is one this version can't read: the pawn here isn't sent over it.
        var isUnreadable: Bool?
    }

    /// The iCloud account the records describe, as CloudKit names its user.
    var account: String?
    /// By the pawn's ID.
    var records: [String: Entry] = [:]

    static func read(from folder: URL) -> CustomPawnLedger {
        let file = folder.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: file) else { return CustomPawnLedger() }
        return (try? JSONDecoder().decode(CustomPawnLedger.self, from: data)) ?? CustomPawnLedger()
    }

    func save(to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            try encoder.encode(self).write(to: folder.appendingPathComponent(Self.fileName), options: .atomic)
        } catch {
            throw PawnLibraryError.saveFailed("\(Self.fileName): \(error.localizedDescription)")
        }
    }
}
