import Foundation
@testable import PawnShopCore
import TablesideShared
import Testing

/// Finding Scrollkeeper's downloads: in the App Group, where Scrollkeeper keeps them, or the folder the user picked.
@Suite struct ScrollkeeperFolderTests {
    private let defaults: UserDefaults
    private let suiteName = "ScrollkeeperFolderTests-\(UUID().uuidString)"

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    @Test func readsScrollkeepersOwnFolderWhenItCan() throws {
        let folder = try Self.makeFolder()
        #expect(ScrollkeeperFolder(defaults: defaults, defaultLocation: folder).open() == folder)
    }

    @Test func asksForTheFolderWhenItCannotBeRead() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)")
        #expect(ScrollkeeperFolder(defaults: defaults, defaultLocation: missing).open() == nil)
    }

    @Test func remembersThePickedFolder() throws {
        let picked = try Self.makeFolder()
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)")
        try ScrollkeeperFolder(defaults: defaults, defaultLocation: missing).remember(picked)

        let opened = ScrollkeeperFolder(defaults: defaults, defaultLocation: missing).open()
        #expect(opened?.resolvingSymlinksInPath() == picked.resolvingSymlinksInPath())
    }

    @Test func forgetsAPickedFolderThatIsGone() throws {
        let picked = try Self.makeFolder()
        let fallback = try Self.makeFolder()
        try ScrollkeeperFolder(defaults: defaults, defaultLocation: fallback).remember(picked)
        try FileManager.default.removeItem(at: picked)

        #expect(ScrollkeeperFolder(defaults: defaults, defaultLocation: fallback).open() == fallback)
    }

    @Test func looksInTheUsersLibrary() {
        #expect(ScrollkeeperFolder.defaultLocation.path.hasSuffix("/Library/Application Support/Scrollkeeper/Files"))
        #expect(!ScrollkeeperFolder.defaultLocation.path.contains("/Containers/"))
    }

    @Test func readsTheDownloadsInTheAppGroupFirst() throws {
        let shared = try Self.makeSharedFolder(isShared: true)
        let picked = try Self.makeFolder()
        try folder(shared: shared).remember(picked)

        #expect(folder(shared: shared).open() == shared.appendingPathComponent("Files", isDirectory: true))
    }

    @Test func leavesAFolderChosenInScrollkeeperToThePicker() throws {
        let shared = try Self.makeSharedFolder(isShared: false, chosen: "/Volumes/Library/Paizo")
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)")

        let scrollkeeper = ScrollkeeperFolder(defaults: defaults, defaultLocation: missing, sharedFolder: shared)
        #expect(scrollkeeper.open() == nil)
        #expect(scrollkeeper.suggestedLocation.path == "/Volumes/Library/Paizo")
    }

    @Test func usesTheGroupsFilesWithoutAListItCanRead() throws {
        let shared = try Self.makeFolder()
        let files = shared.appendingPathComponent("Files", isDirectory: true)
        try FileManager.default.createDirectory(at: files.appendingPathComponent("Pawns"),
                                                withIntermediateDirectories: true)
        try Data(#"{"formatVersion": 99}"#.utf8).write(to: shared.appendingPathComponent(ScrollkeeperLibrary.fileName))

        #expect(folder(shared: shared).open() == files)
    }

    @Test func skipsAnEmptyGroupFolder() throws {
        let shared = try Self.makeFolder()
        let fallback = try Self.makeFolder()
        let scrollkeeper = ScrollkeeperFolder(defaults: defaults, defaultLocation: fallback, sharedFolder: shared)

        #expect(scrollkeeper.open() == fallback)
        #expect(scrollkeeper.suggestedLocation == fallback)
    }

    private func folder(shared: URL) -> ScrollkeeperFolder {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)")
        return ScrollkeeperFolder(defaults: defaults, defaultLocation: missing, sharedFolder: shared)
    }

    /// Scrollkeeper's folder in the App Group with its library list and a `Files` folder.
    private static func makeSharedFolder(isShared: Bool, chosen: String? = nil) throws -> URL {
        let shared = try makeFolder()
        try FileManager.default.createDirectory(at: shared.appendingPathComponent("Files/Pawns"),
                                                withIntermediateDirectories: true)
        let library = ScrollkeeperLibrary(generatedAt: Date(), downloadFolder: .init(isShared: isShared, path: chosen),
                                          titles: [])
        try library.encoded().write(to: shared.appendingPathComponent(ScrollkeeperLibrary.fileName))
        return shared
    }

    private static func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Scrollkeeper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
