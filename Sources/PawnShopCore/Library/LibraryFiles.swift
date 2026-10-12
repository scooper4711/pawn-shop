import ArtExtraction
import CryptoKit
import Foundation

/// The file the library imports for a PDF or picture, recognized again by its digest and size.
extension PawnLibrary {
    /// A two-file deck's art PDF, the folder of a deck sold as pictures, or else the file itself.
    static func libraryFile(for url: URL) -> URL {
        ImageDeck.containing(url)?.folder ?? CardDeck.containing(url)?.artFile ?? url
    }

    /// The product's title: a deck's, or else one made from the file name.
    static func title(of url: URL) -> String {
        ImageDeck.containing(url)?.title ?? CardDeck.containing(url)?.title
            ?? PawnSource.title(fromFileName: url.lastPathComponent)
    }

    /// A file's size, or the total size of a folder's files; nil when it can't be read.
    static func byteCount(of url: URL) -> Int? {
        guard let files = folderFiles(url) else { return fileSize(url) }
        return files.reduce(0) { $0 + (fileSize($1) ?? 0) }
    }

    /// SHA-256 of a file; of a folder, of its files' names and sizes, which a deck of pictures doesn't change.
    static func digest(of url: URL) throws -> String {
        if let files = folderFiles(url) {
            let listing = files.map { "\($0.lastPathComponent):\(fileSize($0) ?? 0)" }.joined(separator: "\n")
            return hex(SHA256.hash(data: Data(listing.utf8)))
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw PawnLibraryError.unreadableFile(url.lastPathComponent)
        }
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hash.update(data: chunk)
        }
        return hex(hash.finalize())
    }

    static func isFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// The files in `url` sorted by name, without hidden ones, or nil when it isn't a folder.
    private static func folderFiles(_ url: URL) -> [URL]? {
        guard isFolder(url), let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            return nil
        }
        return names.filter { !$0.hasPrefix(".") }.sorted().map(url.appendingPathComponent)
    }

    private static func fileSize(_ url: URL) -> Int? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension PawnLibrary {
    /// True for a file or folder an import can read: a PDF, or an item deck sold as pictures, or one of its
    /// pictures.
    public static func isImportable(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf" || ImageDeck.containing(url) != nil
    }
}
