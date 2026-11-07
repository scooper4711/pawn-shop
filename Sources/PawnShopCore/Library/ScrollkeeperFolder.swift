import Foundation
import TablesideShared

/// Scrollkeeper's downloads folder as Pawn Shop reaches it: in the Tableside Toolkit's App Group, where a sandboxed
/// Scrollkeeper keeps them and says so in its library list; else the folder the user picked once, remembered with a
/// bookmark; else where Scrollkeeper kept them before it ran in the sandbox.
public struct ScrollkeeperFolder {
    public static let bookmarkKey = "scrollkeeperFolderBookmark"

    /// Scrollkeeper's own downloads folder, `~/Library/Application Support/Scrollkeeper/Files`, in the user's home
    /// folder rather than the sandbox's.
    public static var defaultLocation: URL {
        realHomeDirectory.appendingPathComponent("Library/Application Support/Scrollkeeper/Files", isDirectory: true)
    }

    private let defaults: UserDefaults
    private let defaultLocation: URL
    /// Scrollkeeper's folder in the App Group; nil when Pawn Shop isn't in the group.
    private let sharedFolder: URL?

    public init(defaults: UserDefaults = .standard, defaultLocation: URL = Self.defaultLocation,
                sharedFolder: URL? = ToolkitGroup.scrollkeeperFolder()) {
        self.defaults = defaults
        self.defaultLocation = defaultLocation
        self.sharedFolder = sharedFolder
    }

    /// The folder to read, with access to it until the app quits; nil when the user has to pick it.
    public func open() -> URL? {
        if let folder = sharedDownloads() { return folder }
        if let folder = rememberedFolder() { return folder }
        return Self.canList(defaultLocation) ? defaultLocation : nil
    }

    /// Where to start the folder picker: the download folder the user chose in Scrollkeeper, when its library list
    /// gives one, else where Scrollkeeper used to keep its downloads.
    public var suggestedLocation: URL {
        guard let folder = sharedFolder, case let .loaded(library) = ScrollkeeperLibrary.read(from: folder),
              !library.downloadFolder.isShared, let path = library.downloadFolder.path
        else { return defaultLocation }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Remembers the folder the user picked, so `open()` finds it after the app restarts.
    public func remember(_ folder: URL) throws {
        let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                                               relativeTo: nil)
        defaults.set(bookmark, forKey: Self.bookmarkKey)
    }

    private func rememberedFolder() -> URL? {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil,
                                    bookmarkDataIsStale: &isStale)
        else { return nil }
        let isAccessing = folder.startAccessingSecurityScopedResource()
        guard Self.canList(folder) else {
            if isAccessing { folder.stopAccessingSecurityScopedResource() }
            return nil
        }
        if isStale { try? remember(folder) }
        return folder
    }

    /// The downloads in the App Group: where the library list says they are, or without a list Pawn Shop can read,
    /// the group's `Files` when it holds any. Nil when the user chose another folder in Scrollkeeper.
    private func sharedDownloads() -> URL? {
        guard let folder = sharedFolder else { return nil }
        if case let .loaded(library) = ScrollkeeperLibrary.read(from: folder) {
            return library.downloadFolderURL(in: folder).flatMap { Self.canList($0) ? $0 : nil }
        }
        let files = folder.appendingPathComponent("Files", isDirectory: true)
        let contents = try? FileManager.default.contentsOfDirectory(atPath: files.path)
        return (contents ?? []).contains { !$0.hasPrefix(".") } ? files : nil
    }

    private static func canList(_ folder: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) != nil
    }

    /// The user's home folder; in the sandbox `FileManager` answers with the app's container instead.
    private static var realHomeDirectory: URL {
        guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
    }
}
