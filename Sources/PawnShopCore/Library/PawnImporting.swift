import ArtExtraction
import Foundation
import SharedLibraries

/// A PDF read and ready to add to the library (`ArtLibrary.prepare`).
public typealias PreparedImport = PreparedArt

/// What an import added.
public struct ImportReport: Equatable, Sendable {
    public var sourceTitle: String
    /// New pawns.
    public var added = 0
    /// Pawns whose art was already in the library from another product.
    public var alreadyKnown = 0
    /// Outlines with no name printed.
    public var unnamed: [UnnamedOutline] = []
    /// Pawns with no name printed that took the name of the same art in another product.
    public var namedFromOtherProducts = 0
    /// Pawns added with a stand-in name, waiting to be named.
    public var needingNames = 0
    /// True when the PDF had been imported before, so nothing changed.
    public var wasImported = false
    /// True when a PDF imported before was read again by a newer reader.
    public var reread = false
    /// Pages printed as one flattened picture, whose pawns can't be read (zero-based).
    public var unreadablePages: [Int] = []
    /// Items' pictures from an item deck, kept for their cards (`ItemArtwork`).
    public var itemArtAdded = 0

    public init(sourceTitle: String, unnamed: [UnnamedOutline] = [], unreadablePages: [Int] = []) {
        self.sourceTitle = sourceTitle
        self.unnamed = unnamed
        self.unreadablePages = unreadablePages
    }

    /// The shared library's report on a PDF, with what its extraction found.
    init(_ report: ArtImportReport, of prepared: PreparedImport, reread: Bool) {
        self.init(sourceTitle: report.sourceTitle, unnamed: prepared.extraction.unnamed,
                  unreadablePages: prepared.extraction.unreadablePages)
        let found = prepared.extraction.pawns
        let isItemDeck = !found.isEmpty && found.allSatisfy(\.isItem)
        added = isItemDeck ? 0 : report.added
        alreadyKnown = isItemDeck ? 0 : report.alreadyKnown
        itemArtAdded = isItemDeck ? report.added + report.alreadyKnown : 0
        namedFromOtherProducts = report.namedFromOtherProducts
        needingNames = report.needingNames
        wasImported = report.wasImported || report.isReadByAnotherApp
        self.reread = reread && !wasImported
    }
}

extension PawnLibrary {
    /// Reads a PDF's pawns. It touches nothing in the library, so it can run off the main thread.
    public static func prepareImport(of url: URL) throws -> PreparedImport {
        guard FileManager.default.isReadableFile(atPath: ArtLibrary.libraryFile(for: url).path) else {
            throw PawnLibraryError.unreadableFile(url.lastPathComponent)
        }
        return try ArtLibrary.prepare(url)
    }

    /// Adds a prepared PDF's pawns to the shared library, keeping a copy of it (R1.9), and reads the change.
    @discardableResult
    public func commit(_ prepared: PreparedImport) throws -> ImportReport {
        let wasRead = sharedSources[prepared.digest] != nil
        // A deck sold as pictures isn't a PDF: its items' pictures are kept on their own, not the folder.
        let location: SourceLocation = Self.isFolder(prepared.file) ? .referenced(try FileReference(prepared.file))
                                                                   : .kept
        let report = try shared.commit(prepared, location: location)
        own.importedFiles[prepared.file.path] = OwnLibrary.ImportedFile(byteCount: prepared.byteCount,
                                                                        digest: prepared.digest)
        own.readAgain[prepared.digest] = nil
        try saveOwn()
        try refresh()
        return ImportReport(report, of: prepared, reread: wasRead)
    }

    /// Imports one PDF on the calling thread.
    @discardableResult
    public func importPDF(at url: URL) throws -> ImportReport {
        try commit(Self.prepareImport(of: url))
    }

    /// True when the PDF at `url` was imported here and read by the current reader: recognized by its path and size,
    /// or else its contents. Either PDF of a two-file deck stands for the deck, and any picture of a deck sold as
    /// pictures for its folder. A PDF only another app read from where it is is imported, so Pawn Shop keeps a copy.
    public func hasImported(_ file: URL) -> Bool {
        let url = ArtLibrary.libraryFile(for: file)
        let size = Self.byteCount(of: url) ?? -1
        let known = own.importedFiles[url.path].flatMap { $0.byteCount == size ? $0.digest : nil }
        guard let digest = known ?? (try? ArtLibrary.digest(of: url)), let source = sharedSources[digest] else {
            return false
        }
        return source.readerVersion >= PawnExtractor.version(of: url) && (source.isKept || Self.isFolder(url))
    }

    /// The files to import for `urls`: each once, a two-file deck as its art PDF, and a deck sold as pictures as
    /// its folder.
    public static func importableFiles(_ urls: [URL]) -> [URL] {
        var files: [URL] = []
        for url in urls.map(ArtLibrary.libraryFile(for:)) where !files.contains(url) {
            files.append(url)
        }
        return files
    }

    /// True for a file or folder an import can read: a PDF, or an item deck sold as pictures, or one of its
    /// pictures.
    public static func isImportable(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf" || ImageDeck.containing(url) != nil
    }

    static func isFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// A file's size, or the total size of a folder's files; nil when it can't be read.
    static func byteCount(of url: URL) -> Int? {
        guard isFolder(url) else { return try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.filter { !$0.hasPrefix(".") }.reduce(0) { total, name in
            let file = url.appendingPathComponent(name)
            return total + ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0)
        }
    }
}

extension ExtractedPawn {
    /// True for an item's picture from an item deck.
    var isItem: Bool {
        switch shape {
        case .item, .drawnItem: true
        case .pawn, .token, .card: false
        }
    }
}
