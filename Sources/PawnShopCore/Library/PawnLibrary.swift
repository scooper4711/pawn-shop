import CryptoKit
import Foundation

/// A PDF read and ready to add to the library.
public struct PreparedImport: Sendable {
    public let file: URL
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
    /// Outlines with no name printed, imported as numbered "Unnamed" pawns.
    public var unnamed: [UnnamedOutline] = []
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
    public private(set) var pawns: [Pawn] = []

    /// `~/Library/Application Support/Pawn Shop`.
    public static var defaultFolder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Pawn Shop", isDirectory: true)
    }

    /// Opens the library in `folder`, creating it when it doesn't exist yet.
    public init(folder: URL = PawnLibrary.defaultFolder) throws {
        self.folder = folder
        try FileManager.default.createDirectory(at: sourcesFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: customFolder, withIntermediateDirectories: true)
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
    public func hasImported(_ url: URL) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
        if sources.contains(where: { $0.originalPath == url.path && $0.byteCount == size }) { return true }
        return (try? Self.digest(of: url)).map { source(id: $0) != nil } ?? false
    }

    /// Reads a PDF's pawns. It touches nothing in the library, so it can run off the main thread.
    public static func prepareImport(of url: URL) throws -> PreparedImport {
        let digest = try digest(of: url)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        let extraction = try PawnExtractor.extract(from: url)
        return PreparedImport(file: url, digest: digest, byteCount: size, extraction: extraction)
    }

    /// Adds a prepared PDF's pawns, merging art the library already has, and saves.
    @discardableResult
    public func commit(_ prepared: PreparedImport) throws -> ImportReport {
        let title = PawnSource.title(fromFileName: prepared.file.lastPathComponent)
        var report = ImportReport(sourceTitle: title, unnamed: prepared.extraction.unnamed)
        guard source(id: prepared.digest) == nil else {
            report.wasImported = true
            return report
        }
        try copySource(prepared)
        sources.append(PawnSource(id: prepared.digest, title: title, importedAt: Date(),
                                  originalPath: prepared.file.path, byteCount: prepared.byteCount))
        for found in prepared.extraction.pawns {
            merge(found, from: prepared.digest, into: &report)
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
        try update(pawn)
    }

    /// Removes pawns, and any custom art files only they used, and saves.
    public func remove(_ ids: Set<UUID>) throws {
        for pawn in pawns where ids.contains(pawn.id) {
            if case .custom(let art) = pawn.art {
                try? FileManager.default.removeItem(at: customFolder.appendingPathComponent(art.imageFile))
            }
        }
        pawns.removeAll { ids.contains($0.id) }
        try save()
    }

    private func merge(_ found: ExtractedPawn, from sourceID: String, into report: inout ImportReport) {
        let appearance = Appearance(sourceID: sourceID, copies: found.copies)
        if let index = pawns.firstIndex(where: {
            $0.name == found.name && $0.size == found.size && $0.fingerprint.matches(found.fingerprint)
        }) {
            pawns[index].appearances.append(appearance)
            report.alreadyKnown += 1
        } else {
            pawns.append(Pawn(name: found.name, size: found.size,
                              art: .pdf(sourceID: sourceID, front: found.front, back: found.back),
                              fingerprint: found.fingerprint, appearances: [appearance]))
            report.added += 1
        }
    }

    private func copySource(_ prepared: PreparedImport) throws {
        let destination = fileURL(forSource: prepared.digest)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        do {
            try FileManager.default.copyItem(at: prepared.file, to: destination)
        } catch {
            let file = prepared.file.lastPathComponent
            throw PawnLibraryError.saveFailed("copying \(file): \(error.localizedDescription)")
        }
    }

    func save() throws {
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

    public func sourceFile(id: String) -> URL { sources.appendingPathComponent("\(id).pdf") }
}

/// The library file's contents.
struct StoredLibrary: Codable {
    var version = 1
    var sources: [PawnSource]
    var pawns: [Pawn]
}
