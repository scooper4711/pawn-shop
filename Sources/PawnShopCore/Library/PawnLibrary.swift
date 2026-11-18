import ArtExtraction
import Foundation
import SharedLibraries
import TablesideShared

public enum PawnLibraryError: Error, Equatable, CustomStringConvertible {
    case unreadableFile(String)
    case saveFailed(String)

    public var description: String {
        switch self {
        case .unreadableFile(let file): "Pawn import failed: \(file) could not be read"
        case .saveFailed(let reason): "Saving the pawn library failed: \(reason)"
        }
    }
}

/// The pawns of every imported PDF, kept in the art library Pawn Shop shares with Turnkeeper and Field Guide
/// (R2.1), and the custom pawns, kept in a folder of Pawn Shop's own.
public final class PawnLibrary {
    /// Pawn Shop's library before the shared one, moved into it once (`LibraryMoving.swift`).
    static let indexFile = "library.json"
    /// The library as version 1 saved it, kept when its pawns were given their keys.
    static let version1File = "library-v1.json"

    /// Pawn Shop's own folder: custom pawns' art and `OwnLibrary`.
    public let folder: URL
    public let shared: SharedLibrary
    public internal(set) var sources: [PawnSource] = []
    public internal(set) var pawns: [Pawn] = []
    /// The items' pictures from imported item decks.
    public internal(set) var itemArt: [ItemArtwork] = []
    var own = OwnLibrary()
    /// The shared library's art, notes and sources as last read, and its change counter then.
    var entries: [UUID: SharedArtEntry] = [:]
    var notes: [UUID: ArtNote] = [:]
    var sharedSources: [String: SharedSource] = [:]
    var counter: Int64 = 0
    /// Each print's key, with the ID of its art.
    var printKeys: [UUID: UUID] = [:]
    /// Pawns by ID, as indexes into `pawns`.
    var pawnIndexes: [UUID: Int] = [:]
    /// Pawns whose notes changed and aren't saved yet (`setTags`, `setSuggestedName`).
    var unsavedNotes: Set<UUID> = []

    /// `~/Library/Application Support/Pawn Shop`.
    public static var defaultFolder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Pawn Shop", isDirectory: true)
    }

    /// Opens the library in `folder`, over the shared library in the App Group, or else in `folder`'s `Shared`
    /// folder (shared libraries R1.2).
    public convenience init(folder: URL = PawnLibrary.defaultFolder) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let shared = try SharedLibrary.standard(app: .pawnShop, fallback: Self.sharedFallback(in: folder))
        try self.init(folder: folder, shared: shared)
    }

    /// Opens the library in `folder` over `shared`, moving Pawn Shop's old library into it first (R2.16).
    public init(folder: URL, shared: SharedLibrary) throws {
        self.folder = folder
        self.shared = shared
        try FileManager.default.createDirectory(at: folders.custom, withIntermediateDirectories: true)
        own = try OwnLibrary.read(from: folder)
        try moveInIfNeeded()
        try reload()
    }

    /// Where the shared library is kept outside the App Group.
    public static func sharedFallback(in folder: URL) -> URL {
        folder.appendingPathComponent("Shared", isDirectory: true)
    }

    /// Where the library keeps its files; safe to hand to other threads.
    public var folders: LibraryFolders { LibraryFolders(root: folder, shared: shared.folder) }
    public var customFolder: URL { folders.custom }

    /// The kept copy of an imported PDF.
    public func fileURL(forSource id: String) -> URL { folders.sourceFile(id: id) }

    public func source(id: String) -> PawnSource? { sharedSources[id].map(PawnSource.init) }

    /// The pawn answering to `id`: by its own ID, a print's key, or an old ID (R2.14).
    public func pawn(id: UUID) -> Pawn? {
        if let index = pawnIndexes[id] { return pawns[index] }
        if let entryID = printKeys[id], let index = pawnIndexes[entryID] { return pawns[index] }
        guard let entry = try? shared.artEntry(id: id) else { return nil }
        return pawnIndexes[entry.id].map { pawns[$0] }
    }

    // MARK: Reading the shared library

    /// Reads the whole shared library again.
    func reload() throws {
        counter = try shared.changeCounter()
        entries = Dictionary(uniqueKeysWithValues: try shared.artEntries().map { ($0.id, $0) })
        notes = try shared.notes()
        try readSources()
        rebuild()
    }

    /// Reads what the shared library changed since it was last read, by this app or another (R2.1): the art and
    /// notes changed, and those deleted. False when nothing changed.
    @discardableResult
    public func refresh() throws -> Bool {
        let changes = try shared.changes(since: counter)
        guard !changes.isEmpty else { return false }
        for entry in try shared.artEntries(changedSince: counter) { entries[entry.id] = entry }
        for (id, note) in try shared.notes(changedSince: counter) { notes[id] = note }
        for key in changes.deletions[.art] ?? [] {
            UUID(uuidString: key).map { entries[$0] = nil }
        }
        for key in changes.deletions[.notes] ?? [] {
            UUID(uuidString: key).map { notes[$0] = nil }
        }
        try readEntries(losingPrints: changes.deletions[.prints] ?? [])
        if !changes.changedTables.isDisjoint(with: [.sources, .sourceAccess]) || changes.deletions[.sources] != nil {
            try readSources()
        }
        counter = changes.counter
        rebuild()
        return true
    }

    /// Reads again the art that lost prints (named `<key>|<source>`), which may now be other art's or gone.
    private func readEntries(losingPrints rows: [String]) throws {
        let keys = rows.compactMap { $0.split(separator: "|").first.flatMap { UUID(uuidString: String($0)) } }
        for entryID in Set(keys.compactMap { printKeys[$0] }) {
            entries[entryID] = try shared.artEntry(id: entryID).flatMap { $0.id == entryID ? $0 : nil }
        }
    }

    private func readSources() throws {
        sharedSources = Dictionary(uniqueKeysWithValues: try shared.sources().map { ($0.id, $0) })
    }

    /// Makes the pawns, item art and sources from the art and notes read, with the custom pawns.
    func rebuild() {
        let reachable = Set(sharedSources.values.filter(\.isKept).map(\.id))
        var extracted: [Pawn] = []
        var items: [ItemArtwork] = []
        printKeys = [:]
        for entry in entries.values {
            entry.prints.forEach { printKeys[$0.key] = entry.id }
            if entry.artEntry.isItem {
                ItemArtwork(entry: entry).map { items.append($0) }
            } else if !isHidden(entry) {
                extracted.append(Pawn(entry: entry, note: notes[entry.id], reachable: reachable))
            }
        }
        extracted.sort(by: Self.isOrdered)
        pawns = extracted + own.customPawns
        itemArt = items.sorted { $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString : $0.name < $1.name }
        pawnIndexes = Dictionary(uniqueKeysWithValues: pawns.enumerated().map { ($1.id, $0) })
        let used = Set(pawns.flatMap { $0.appearances.map(\.sourceID) } + itemArt.map(\.sourceID))
        sources = sharedSources.values.filter { used.contains($0.id) }.map(PawnSource.init)
            .sorted { $0.title < $1.title }
    }

    /// The library's order: by name, then ID, the same on every launch.
    private static func isOrdered(_ first: Pawn, _ second: Pawn) -> Bool {
        first.name == second.name ? first.id.uuidString < second.id.uuidString : first.name < second.name
    }

    /// True when the user removed the art from Pawn Shop (R2.5), by its ID or any print's key.
    private func isHidden(_ entry: SharedArtEntry) -> Bool {
        guard !own.hidden.isEmpty else { return false }
        return own.hidden.contains(entry.id) || entry.prints.contains { own.hidden.contains($0.key) }
    }
}

/// The folders the library's files are in: Pawn Shop's own, and the shared library's.
public struct LibraryFolders: Hashable, Sendable {
    /// Pawn Shop's folder.
    public let root: URL
    /// The shared library's folder.
    public let shared: URL

    public init(root: URL, shared: URL) {
        self.root = root
        self.shared = shared
    }

    /// The kept PDFs, named by their digest.
    public var sources: URL { shared.appendingPathComponent("Sources", isDirectory: true) }
    /// Images for custom pawns.
    public var custom: URL { root.appendingPathComponent("Custom", isDirectory: true) }
    /// Tokens' art drawn alone, items' pictures cut out of decks sold as pictures, and each art's picture.
    public var pictures: URL { shared.appendingPathComponent("Pictures", isDirectory: true) }
    /// Tokens' art drawn alone (see `TokenArt`).
    public var tokens: URL { pictures }
    /// Items' pictures cut out of decks sold as pictures (see `ItemPicture.drawn`).
    public var items: URL { pictures }

    public func sourceFile(id: String) -> URL { sources.appendingPathComponent("\(id).pdf") }
}

/// Opening the library for trying things out, following other apps' changes, and the iPad's background.
extension PawnLibrary {
    /// Opens the library in `folder` with a shared library of its own, never the App Group's, for trying things out
    /// (`PAWN_SHOP_LIBRARY`).
    public static func local(folder: URL) throws -> PawnLibrary {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let shared = try SharedLibrary(folder: sharedFallback(in: folder), app: .pawnShop)
        return try PawnLibrary(folder: folder, shared: shared)
    }

    /// Calls `onChange` on the main thread whenever an app changes the shared library, this one included.
    public static func observeChanges(_ onChange: @escaping @MainActor @Sendable () -> Void) -> LibraryChangeObserver {
        SharedLibraryChange.observe(onChange)
    }

    /// Lets go of the shared library's file, as the app goes to the background on the iPad (shared libraries R5.4);
    /// the next read or write opens it again.
    public func close() { shared.close() }
}
