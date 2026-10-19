import Foundation
@testable import PawnShopCore
import Testing

/// Finding Scrollkeeper's downloads: where Scrollkeeper keeps them, or the folder the user picked.
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

    private static func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Scrollkeeper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
