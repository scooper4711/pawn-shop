import Foundation

/// Scrollkeeper's downloads folder as Pawn Shop reaches it. Outside the App Sandbox it is read where Scrollkeeper
/// keeps it; in the sandbox the user picks it once, and a bookmark gives Pawn Shop access to it after that.
public struct ScrollkeeperFolder {
    public static let bookmarkKey = "scrollkeeperFolderBookmark"

    /// Scrollkeeper's own downloads folder, `~/Library/Application Support/Scrollkeeper/Files`, in the user's home
    /// folder rather than the sandbox's.
    public static var defaultLocation: URL {
        realHomeDirectory.appendingPathComponent("Library/Application Support/Scrollkeeper/Files", isDirectory: true)
    }

    private let defaults: UserDefaults
    private let defaultLocation: URL

    public init(defaults: UserDefaults = .standard, defaultLocation: URL = Self.defaultLocation) {
        self.defaults = defaults
        self.defaultLocation = defaultLocation
    }

    /// The folder to read, with access to it until the app quits; nil when the user has to pick it.
    public func open() -> URL? {
        if let folder = rememberedFolder() { return folder }
        return Self.canList(defaultLocation) ? defaultLocation : nil
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
