import Foundation
import os

/// What `DocumentsFolder` asks of the file system, so tests can stand in for iCloud.
public protocol UbiquityFileSystem: Sendable {
    /// The container's folder on this device, or nil without iCloud Drive or the container's entitlement.
    func container(_ identifier: String) -> URL?
    func folderExists(at url: URL) -> Bool
    func createFolder(at url: URL) throws
}

/// Pawn Shop's folder in iCloud Drive, where sheets are offered first (R11). The system's document machinery saves
/// there once the app has a ubiquity container; this only sets the container up and makes the `Documents` folder
/// iCloud Drive shows, so the folder appears before the first sheet is saved (R11.1).
public enum DocumentsFolder {
    public static let containerIdentifier = "iCloud.io.github.scooper4711.PawnShop"

    public struct PreparationError: Error, CustomStringConvertible {
        public let folder: URL
        public let underlying: Error
        public var description: String { "Preparing the iCloud Drive folder \(folder.path) failed: \(underlying)" }
    }

    /// Sets the container up and makes its `Documents` folder. Returns the folder, or nil when the app has no iCloud
    /// Drive (signed out, iCloud Drive off, or a build without the entitlement; R11.6). Apple asks that the first call
    /// for a container be made off the main thread, as it can take a while.
    @discardableResult
    public static func prepare(on fileSystem: some UbiquityFileSystem = SystemUbiquityFileSystem()) throws -> URL? {
        guard let container = fileSystem.container(containerIdentifier) else { return nil }
        let documents = container.appendingPathComponent("Documents", isDirectory: true)
        if fileSystem.folderExists(at: documents) { return documents }
        do {
            try fileSystem.createFolder(at: documents)
        } catch {
            throw PreparationError(folder: documents, underlying: error)
        }
        return documents
    }

    /// `prepare(on:)` in the background, at launch. A failure is logged: it only means the folder appears with the
    /// first save.
    @discardableResult
    public static func prepareInBackground(
        on fileSystem: some UbiquityFileSystem = SystemUbiquityFileSystem()
    ) -> Task<Void, Never> {
        Task.detached(priority: .utility) {
            do {
                try prepare(on: fileSystem)
            } catch {
                Logger(subsystem: "io.github.scooper4711.PawnShop", category: "Documents")
                    .error("\(String(describing: error), privacy: .public)")
            }
        }
    }
}

/// The real file system.
public struct SystemUbiquityFileSystem: UbiquityFileSystem {
    public init() {}

    public func container(_ identifier: String) -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: identifier)
    }

    public func folderExists(at url: URL) -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }

    public func createFolder(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
