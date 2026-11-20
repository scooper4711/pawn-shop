import Foundation
import Testing
@testable import PawnShopCore

@Suite struct DocumentsFolderTests {
    /// A file system with an optional container, recording the folders made in it.
    final class StandInFileSystem: UbiquityFileSystem, @unchecked Sendable {
        let containerURL: URL?
        var existing: Set<URL>
        var created: [URL] = []
        var askedFor: [String] = []
        let failure: Error?

        init(container: URL?, existing: Set<URL> = [], failure: Error? = nil) {
            containerURL = container
            self.existing = existing
            self.failure = failure
        }

        func container(_ identifier: String) -> URL? {
            askedFor.append(identifier)
            return containerURL
        }

        func folderExists(at url: URL) -> Bool { existing.contains(url) }

        func createFolder(at url: URL) throws {
            if let failure { throw failure }
            created.append(url)
            existing.insert(url)
        }
    }

    struct DiskFull: Error {}

    let container = URL(fileURLWithPath: "/iCloud/Pawn Shop", isDirectory: true)
    var documents: URL { container.appendingPathComponent("Documents", isDirectory: true) }

    @Test func makesTheDocumentsFolderInPawnShopsContainer() throws {
        let fileSystem = StandInFileSystem(container: container)
        #expect(try DocumentsFolder.prepare(on: fileSystem) == documents)
        #expect(fileSystem.askedFor == ["iCloud.io.github.scooper4711.PawnShop"])
        #expect(fileSystem.created == [documents])
    }

    @Test func leavesAnExistingFolderAlone() throws {
        let fileSystem = StandInFileSystem(container: container, existing: [documents])
        #expect(try DocumentsFolder.prepare(on: fileSystem) == documents)
        #expect(fileSystem.created.isEmpty)
    }

    @Test func doesNothingWithoutICloudDrive() throws {
        let fileSystem = StandInFileSystem(container: nil)
        #expect(try DocumentsFolder.prepare(on: fileSystem) == nil)
        #expect(fileSystem.created.isEmpty)
    }

    @Test func namesTheFolderWhenMakingItFails() {
        let fileSystem = StandInFileSystem(container: container, failure: DiskFull())
        #expect {
            try DocumentsFolder.prepare(on: fileSystem)
        } throws: { error in
            let failure = error as? DocumentsFolder.PreparationError
            return failure?.folder == documents && failure?.underlying is DiskFull
                && "\(error)".contains("Preparing the iCloud Drive folder")
        }
    }

    @Test func preparesInTheBackground() async {
        let fileSystem = StandInFileSystem(container: container)
        await DocumentsFolder.prepareInBackground(on: fileSystem).value
        #expect(fileSystem.created == [documents])
    }

    @Test func aFailureInTheBackgroundIsOnlyLogged() async {
        let fileSystem = StandInFileSystem(container: container, failure: DiskFull())
        await DocumentsFolder.prepareInBackground(on: fileSystem).value
        #expect(fileSystem.created.isEmpty)
    }

    @Test func theSystemFileSystemMakesAndFindsFolders() throws {
        let fileSystem = SystemUbiquityFileSystem()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("DocumentsFolderTests-\(UUID().uuidString)/Documents", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        #expect(!fileSystem.folderExists(at: folder))
        try fileSystem.createFolder(at: folder)
        #expect(fileSystem.folderExists(at: folder))
        // A test process has no iCloud container entitlement.
        #expect(fileSystem.container(DocumentsFolder.containerIdentifier) == nil)
    }
}
