import ArtExtraction
import Foundation
import SharedLibraries

/// Pawn Shop's version 2 library as the shared library takes it in (R2.16): each extracted pawn as art keyed by its
/// ID with the one print the library records, item art keyed by `ArtKey`, a note per pawn, and the files to move.
struct PawnShopMove {
    private(set) var move = LibraryMove(app: .pawnShop, artFolder: nil)
    /// The sources to read again from their original files, as the library records the faces of a pawn's first
    /// product only: those of every pawn printed by more than one product.
    private(set) var readAgain: [String: String] = [:]
    /// The original files, to recognize them without hashing them (`OwnLibrary.importedFiles`).
    private(set) var importedFiles: [String: OwnLibrary.ImportedFile] = [:]
    private let stored: StoredLibrary
    private let oldFolder: URL

    init(stored: StoredLibrary, oldFolder: URL) {
        self.stored = stored
        self.oldFolder = oldFolder
        let shared = Set(stored.pawns.filter { $0.appearances.count > 1 }.flatMap { $0.appearances.map(\.sourceID) })
        for source in stored.sources {
            importedFiles[source.originalPath] = OwnLibrary.ImportedFile(byteCount: source.byteCount,
                                                                         digest: source.id)
            if shared.contains(source.id) { readAgain[source.id] = source.originalPath }
        }
        move.aliases = stored.aliases
        addSources()
        stored.pawns.filter { !$0.isCustom }.forEach { addPawn($0) }
        addItems()
    }

    // MARK: Helpers

    private var sourcesFolder: URL { oldFolder.appendingPathComponent("Sources", isDirectory: true) }

    /// The sources, kept when their PDF is; one to read again as read by no reader yet.
    private mutating func addSources() {
        for source in stored.sources {
            let kept = sourcesFolder.appendingPathComponent("\(source.id).pdf")
            let location: SourceLocation
            if FileManager.default.fileExists(atPath: kept.path) {
                location = .kept
                move.keptPDFs[source.id] = kept
            } else if let reference = Self.reference(to: source.originalPath) {
                location = .referenced(reference)
            } else {
                continue
            }
            let readerVersion = readAgain[source.id] == nil ? source.readerVersion ?? 0 : 0
            move.keyedSources.append(ArtSource(id: source.id, title: source.title,
                                               game: GameSystem(title: source.title), location: location,
                                               byteCount: source.byteCount, readerVersion: readerVersion,
                                               artFound: source.pawnsFound ?? 0))
        }
    }

    /// A pawn as art keyed by its ID, its art's print, and its note. Art from a product printing no names keeps
    /// the stand-in name, and the name the user gave it is the note's.
    private mutating func addPawn(_ pawn: Pawn) {
        guard let print = print(of: pawn) else { return }
        let title = stored.sources.first { $0.id == print.print.sourceID }?.title ?? ""
        let isNameless = stored.isNameless(pawn)
        let standIn = pawn.needsName ? pawn.name : NamelessProducts.standInName(forTitle: title)
        let art = ArtEntry(id: pawn.id, name: isNameless ? standIn : pawn.name,
                           game: GameSystem(title: title), size: pawn.size, traits: pawn.traits,
                           fingerprint: pawn.fingerprint, prints: [], palette: [])
        var entry = SharedArtEntry(art, prints: [print], picture: print.print.tokenFile)
        entry.needsName = isNameless
        move.keyedArt.append(entry)
        let userName = isNameless && !pawn.needsName ? pawn.name : nil
        let note = ArtNote(userName: userName, tags: pawn.tags, tagModel: pawn.tagModel,
                           suggestedName: pawn.suggestedName, isCorrected: pawn.tagsCorrected)
        if note != ArtNote() { move.notes[pawn.id] = note }
    }

    /// The print a pawn's art comes from, keyed by its ID; a token's pictures move under that key.
    private mutating func print(of pawn: Pawn) -> SharedPrint? {
        let copies = pawn.appearances.first?.copies ?? 1
        switch pawn.art {
        case .pdf(let sourceID, let front, let back):
            return SharedPrint(key: pawn.id, print: ArtPrint(sourceID: sourceID, kind: .pawn, face: front,
                                                             copies: copies), back: back)
        case .card(let art):
            return SharedPrint(key: pawn.id, print: ArtPrint(sourceID: art.sourceID, kind: .figure, face: art.face,
                                                             imageIndex: art.imageIndex, copies: copies))
        case .token(let art):
            let front = moveToken(art.frontPicture, as: "\(pawn.id.uuidString).png")
            let back = art.backPicture.map { moveToken($0, as: "\(pawn.id.uuidString)-back.png") }
            return SharedPrint(key: pawn.id, print: ArtPrint(sourceID: art.sourceID, kind: .token, face: pawn.art.front,
                                                             tokenFile: front, copies: copies),
                               backPicture: back)
        case .custom, .picture:
            // A saved picture stands in for a PDF another app or device read: a library of Pawn Shop's own has none.
            return nil
        }
    }

    private mutating func moveToken(_ file: String, as name: String) -> String {
        move.pictureFiles[name] = oldFolder.appendingPathComponent("Tokens", isDirectory: true)
            .appendingPathComponent(file)
        return name
    }

    /// The items' art, keyed by `ArtKey` as an import would key it; a drawn item's picture moves under its key.
    private mutating func addItems() {
        let faces = stored.itemArt.map(Self.face(of:))
        let keys = ArtKey.keys(for: zip(stored.itemArt, faces).map { item, face in
            ArtKeyInput(sourceID: item.sourceID, name: item.name, size: .medium, fingerprint: item.fingerprint,
                        face: face)
        })
        for (index, item) in stored.itemArt.enumerated() {
            let key = keys[index]
            var print = ArtPrint(sourceID: item.sourceID, kind: .item, face: faces[index], copies: 1)
            switch item.picture {
            case .figure(_, let imageIndex):
                print.imageIndex = imageIndex
            case .drawn(let file):
                print.tokenFile = "\(key.uuidString).png"
                let items = oldFolder.appendingPathComponent("Items", isDirectory: true)
                move.pictureFiles["\(key.uuidString).png"] = items.appendingPathComponent(file)
            }
            let title = stored.sources.first { $0.id == item.sourceID }?.title ?? ""
            let art = ArtEntry(id: key, name: item.name, game: GameSystem(title: title), size: .medium, traits: [],
                               fingerprint: item.fingerprint, prints: [], palette: [])
            move.keyedArt.append(SharedArtEntry(art, prints: [SharedPrint(key: key, print: print)],
                                                picture: print.tokenFile))
        }
    }

    /// A reference to the original file; one that is gone stays listed as missing (shared libraries R6.3), as a
    /// reference without a bookmark, which never resolves.
    private static func reference(to path: String) -> FileReference? {
        if let reference = try? FileReference(URL(fileURLWithPath: path)) { return reference }
        struct Missing: Encodable {
            var bookmark = Data()
            let path: String
        }
        guard let data = try? JSONEncoder().encode(Missing(path: path)) else { return nil }
        return try? JSONDecoder().decode(FileReference.self, from: data)
    }

    private static func face(of item: ItemArtwork) -> PawnFace {
        if case .figure(let face, _) = item.picture { return face }
        return PawnFace(pageIndex: 0, rect: .zero, rotation: 0)
    }
}
