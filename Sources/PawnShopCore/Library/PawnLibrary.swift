import CryptoKit
import ArtExtraction
import Foundation

/// A PDF read and ready to add to the library.
public struct PreparedImport: Sendable {
    /// The PDF the library keeps: for a two-file deck of Battle Cards, the one with the art.
    public let file: URL
    /// The product's title.
    public let title: String
    public let digest: String
    public let byteCount: Int
    public let extraction: ExtractionResult
}

/// What an import added.
public struct ImportReport: Equatable, Sendable {
    public var sourceTitle: String
    /// New pawns.
    public var added = 0
    /// Pawns whose art was already in the library from another product.
    public var alreadyKnown = 0
    /// Outlines with no name printed.
    public var unnamed: [UnnamedOutline] = []
    /// Pawns now drawn from a sharper picture of the same painting, from Battle Cards.
    public var sharpened = 0
    /// Pawns with no name printed that took the name of the same art in another product.
    public var namedFromOtherProducts = 0
    /// Pawns added with a stand-in name, waiting to be named.
    public var needingNames = 0
    /// True when the PDF had been imported before, so nothing changed.
    public var wasImported = false
}

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

/// The pawns collected from every imported PDF, kept in a folder between launches.
public final class PawnLibrary {
    static let indexFile = "library.json"

    public let folder: URL
    public private(set) var sources: [PawnSource] = []
    public internal(set) var pawns: [Pawn] = []
    /// Reads pawns' pictures to compare them while importing.
    private(set) lazy var figures = FigureReader(folders: folders)
    /// Pawn indexes by name (see `nameKey`), while importing; nil until needed.
    var paintingIndex: [String: [Int]]?

    /// `~/Library/Application Support/Pawn Shop`.
    public static var defaultFolder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Pawn Shop", isDirectory: true)
    }

    /// Opens the library in `folder`, creating it when it doesn't exist yet.
    public init(folder: URL = PawnLibrary.defaultFolder) throws {
        self.folder = folder
        try FileManager.default.createDirectory(at: sourcesFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: customFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folders.tokens, withIntermediateDirectories: true)
        let index = folder.appendingPathComponent(Self.indexFile)
        guard FileManager.default.fileExists(atPath: index.path) else { return }
        let stored = try JSONDecoder().decode(StoredLibrary.self, from: Data(contentsOf: index))
        sources = stored.sources
        pawns = stored.pawns
    }

    /// Where the library keeps its files; safe to hand to other threads.
    public var folders: LibraryFolders { LibraryFolders(root: folder) }
    var sourcesFolder: URL { folders.sources }
    public var customFolder: URL { folders.custom }

    /// The library's copy of an imported PDF.
    public func fileURL(forSource id: String) -> URL { folders.sourceFile(id: id) }

    public func source(id: String) -> PawnSource? { sources.first { $0.id == id } }

    public func pawn(id: UUID) -> Pawn? { pawns.first { $0.id == id } }

    /// True when the PDF at `url` was imported before: recognized by its path and size, or else its contents.
    /// Either PDF of a two-file deck of Battle Cards stands for the deck. A PDF in which an older reader found
    /// nothing is not counted, so that it is tried again (see `isWorthRereading`).
    public func hasImported(_ file: URL) -> Bool {
        let url = CardDeck.containing(file)?.artFile ?? file
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
        let imported = sources.filter { !isWorthRereading($0) }
        if imported.contains(where: { $0.originalPath == url.path && $0.byteCount == size }) { return true }
        return (try? Self.digest(of: url)).map { digest in imported.contains { $0.id == digest } } ?? false
    }

    /// True when an older reader (`PawnExtractor.version`) found no pawns in the source, so the current one may.
    /// For products imported before the count was recorded, no pawn coming from it counts as none found.
    func isWorthRereading(_ source: PawnSource) -> Bool {
        guard (source.readerVersion ?? 0) < PawnExtractor.version else { return false }
        guard let found = source.pawnsFound else {
            return !pawns.contains { $0.appearances.contains { $0.sourceID == source.id } }
        }
        return found == 0
    }

    /// The PDFs to import for `urls`: each once, and a two-file deck of Battle Cards as its art PDF.
    public static func importableFiles(_ urls: [URL]) -> [URL] {
        var files: [URL] = []
        for url in urls.map({ CardDeck.containing($0)?.artFile ?? $0 }) where !files.contains(url) {
            files.append(url)
        }
        return files
    }

    /// Reads a PDF's pawns. It touches nothing in the library, so it can run off the main thread.
    public static func prepareImport(of url: URL) throws -> PreparedImport {
        let deck = CardDeck.containing(url)
        let file = deck?.artFile ?? url
        let digest = try digest(of: file)
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
        let extraction = try PawnExtractor.extract(from: file)
        return PreparedImport(file: file, title: deck?.title ?? PawnSource.title(fromFileName: url.lastPathComponent),
                              digest: digest, byteCount: size, extraction: extraction)
    }

    /// Adds a prepared PDF's pawns, merging art the library already has, and saves.
    @discardableResult
    public func commit(_ prepared: PreparedImport) throws -> ImportReport {
        let title = prepared.title
        var report = ImportReport(sourceTitle: title, unnamed: prepared.extraction.unnamed)
        if let known = source(id: prepared.digest), !isWorthRereading(known) {
            report.wasImported = true
            return report
        }
        sources.filter { ($0.id == prepared.digest || $0.originalPath == prepared.file.path) && isWorthRereading($0) }
            .forEach(forget)
        // A PDF with no pawns is not kept: nothing would be drawn from it.
        if !prepared.extraction.pawns.isEmpty { try copySource(prepared) }
        sources.append(PawnSource(id: prepared.digest, title: title, importedAt: Date(),
                                  originalPath: prepared.file.path, byteCount: prepared.byteCount,
                                  pawnsFound: prepared.extraction.pawns.count, readerVersion: PawnExtractor.version))
        let source = sources[sources.count - 1]
        defer {
            figures.forgetPages()
            paintingIndex = nil
        }
        for found in prepared.extraction.pawns {
            try merge(found, from: source, into: &report)
        }
        try save()
        return report
    }

    /// Imports one PDF on the calling thread.
    @discardableResult
    public func importPDF(at url: URL) throws -> ImportReport {
        try commit(Self.prepareImport(of: url))
    }

    /// Adds a pawn made from the user's own art and saves.
    public func add(_ pawn: Pawn) throws {
        pawns.append(pawn)
        try save()
    }

    /// Replaces the pawn with the same id and saves.
    public func update(_ pawn: Pawn) throws {
        guard let index = pawns.firstIndex(where: { $0.id == pawn.id }) else { return }
        pawns[index] = pawn
        try save()
    }

    /// Renames a pawn and saves; a blank name is ignored.
    public func rename(_ id: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var pawn = pawn(id: id) else { return }
        pawn.name = trimmed
        pawn.needsName = false
        pawn.suggestedName = ""
        try update(pawn)
    }

    /// Records the tags `model` chose for a pawn, without saving, since tagging a whole library would otherwise
    /// write it out once per pawn; call `save()` after a batch. Tags the user corrected are kept.
    public func setTags(_ tags: [String], by model: String, of id: UUID) {
        guard let index = pawns.firstIndex(where: { $0.id == id }), !pawns[index].tagsCorrected else { return }
        pawns[index].tags = tags
        pawns[index].tagModel = model
    }

    /// Replaces a pawn's tags with the user's own, which tagging then keeps, and saves.
    public func correctTags(_ tags: [String], of id: UUID) throws {
        guard var pawn = pawn(id: id) else { return }
        pawn.tags = PawnTags.cleaned(tags)
        pawn.tagsCorrected = true
        try update(pawn)
    }

    /// Records the name the model suggests for a pawn needing one, without saving, like `setTags`.
    public func setSuggestedName(_ name: String, of id: UUID) {
        guard let index = pawns.firstIndex(where: { $0.id == id }) else { return }
        pawns[index].suggestedName = name
    }

    /// Removes pawns, and any custom art and token pictures only they used, and saves.
    public func remove(_ ids: Set<UUID>) throws {
        for pawn in pawns where ids.contains(pawn.id) {
            switch pawn.art {
            case .custom(let art):
                try? FileManager.default.removeItem(at: customFolder.appendingPathComponent(art.imageFile))
            case .token(let art):
                for file in art.pictures {
                    try? FileManager.default.removeItem(at: folders.tokens.appendingPathComponent(file))
                }
            case .pdf, .card:
                break
            }
        }
        pawns.removeAll { ids.contains($0.id) }
        try save()
    }

    /// Drops a source in which nothing was found, and its copy, before its PDF is read again.
    private func forget(_ source: PawnSource) {
        sources.removeAll { $0.id == source.id }
        try? FileManager.default.removeItem(at: fileURL(forSource: source.id))
    }

    private func copySource(_ prepared: PreparedImport) throws {
        let destination = fileURL(forSource: prepared.digest)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        do {
            // Copy the PDF itself, not a link to it, so the library survives the original moving.
            try FileManager.default.copyItem(at: prepared.file.resolvingSymlinksInPath(), to: destination)
        } catch {
            let file = prepared.file.lastPathComponent
            throw PawnLibraryError.saveFailed("copying \(file): \(error.localizedDescription)")
        }
    }

    public func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(StoredLibrary(sources: sources, pawns: pawns))
            try data.write(to: folder.appendingPathComponent(Self.indexFile), options: .atomic)
        } catch {
            throw PawnLibraryError.saveFailed(error.localizedDescription)
        }
    }

    static func digest(of url: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw PawnLibraryError.unreadableFile(url.lastPathComponent)
        }
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hash.update(data: chunk)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// The folders inside a library folder.
public struct LibraryFolders: Hashable, Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    /// Copies of the imported PDFs, named by their digest.
    public var sources: URL { root.appendingPathComponent("Sources", isDirectory: true) }
    /// Images for custom pawns.
    public var custom: URL { root.appendingPathComponent("Custom", isDirectory: true) }
    /// Tokens' art drawn alone (see `TokenArt`).
    public var tokens: URL { root.appendingPathComponent("Tokens", isDirectory: true) }

    public func sourceFile(id: String) -> URL { sources.appendingPathComponent("\(id).pdf") }
}

/// The library file's contents.
struct StoredLibrary: Codable {
    var version = 1
    var sources: [PawnSource]
    var pawns: [Pawn]
}
