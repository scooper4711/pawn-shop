import Foundation
import Observation
import PawnShopCore
import TablesideShared
import TablesideSync

/// Progress of a batch of imports.
struct ImportProgress: Equatable {
    var fileName: String
    var done: Int
    var total: Int
}

/// The shared pawn library, observed by every sheet window.
@MainActor
@Observable
final class LibraryModel {
    static let shared = LibraryModel()

    private(set) var pawns: [Pawn] = []
    private(set) var sources: [PawnSource] = []
    /// The items' art from imported item decks, which their cards show.
    private(set) var itemArt: [ItemArtwork] = []
    private(set) var importProgress: ImportProgress?
    /// The outcome of the last import batch, shown until dismissed.
    var importSummary: String?
    var errorMessage: String?
    /// On the iPad, the file browser for Import PDF… and for Scrollkeeper's folder; the Mac uses open panels.
    var isChoosingPDFs = false
    var isChoosingScrollkeeperFolder = false
    /// Whether the library syncs through iCloud (R10.5).
    var syncStatus = SyncStatus.withoutSync(containerIdentifier: LibrarySync.bundleContainer)
    /// True once syncing has started: the build names the container and the device has an iCloud account.
    var syncs = false
    /// Why custom pawns from another device couldn't all be merged in; nil when they could.
    var syncProblem: String?
    /// Counts the times pictures arrived from iCloud, so that what shows them is drawn again (R10.4).
    var picturesFetched = 0
    /// True while an export or a print waits for its sheet's pictures.
    var isWaitingForPictures = false

    @ObservationIgnored private(set) var library: PawnLibrary?
    @ObservationIgnored private(set) var renderer: PawnRenderer?
    @ObservationIgnored private(set) var backgroundRenderer: BackgroundRenderer?
    /// Hears of other apps' changes to the shared library (R2.1).
    @ObservationIgnored private var changeObserver: LibraryChangeObserver?
    /// Syncing, while the build and the device have iCloud (`LibraryModel+Sync.swift`).
    @ObservationIgnored var sync: LibrarySync?
    @ObservationIgnored var customPawnSync: CustomPawnSync?
    @ObservationIgnored var pictureRequests: PictureRequests?
    /// The library's count of changes to custom pawns' settings that syncing was last told of.
    @ObservationIgnored var customPawnChangesTold = 0
    /// The reading of the shared library's changes that is waiting, so a run of changes is read once.
    @ObservationIgnored private var changesToRead: Task<Void, Never>?
    static let changeReadingInterval: Duration = .milliseconds(500)
    /// Every Pathfinder and Starfinder item, bundled with the app; empty in a build without `Generated`.
    @ObservationIgnored let catalog = ItemCatalog.bundled()

    private init() {
        do {
            let library = try Self.openLibrary()
            self.library = library
            renderer = PawnRenderer(library: library)
            backgroundRenderer = BackgroundRenderer(folders: library.folders)
            refresh()
            changeObserver = PawnLibrary.observeChanges { [weak self] in self?.libraryChanged() }
            readAgainAtLaunch()
            startSync()
        } catch {
            errorMessage = "Opening the pawn library failed: \(error)"
        }
    }

    /// The library; `PAWN_SHOP_LIBRARY` points the app at another folder, with a shared library of its own, for
    /// trying things out.
    private static func openLibrary() throws -> PawnLibrary {
        guard let path = ProcessInfo.processInfo.environment["PAWN_SHOP_LIBRARY"] else { return try PawnLibrary() }
        return try PawnLibrary.local(folder: URL(fileURLWithPath: path))
    }

    /// Reads what another app changed in the shared library, or what changed while the app was in the background.
    /// A run of changes is read at most twice a second: a first sync merges a library in over hundreds of
    /// changes, and reading ten thousand pawns again for each kept the window from answering.
    func libraryChanged() {
        guard changesToRead == nil else { return }
        changesToRead = Task {
            try? await Task.sleep(for: Self.changeReadingInterval)
            guard !Task.isCancelled else { return }
            changesToRead = nil
            readLibraryChanges()
        }
    }

    private func readLibraryChanges() {
        do {
            if try library?.refresh() == true { refresh() }
        } catch {
            errorMessage = "Reading the shared library failed: \(error)"
        }
        // A creature another app or device deleted took its pawn's settings with it.
        tellSyncOfCustomPawnChanges()
    }

    /// Lets go of the shared library's file as the app goes to the background on the iPad; syncing lets go of it
    /// too, after each thing it still does there.
    func close() {
        // A reading still waiting would open the file again after it was let go; `open()` reads what was missed.
        changesToRead?.cancel()
        changesToRead = nil
        library?.close()
        syncClosed(true)
    }

    /// Reads again, from where they were imported, the PDFs an older reader read (R1.7) and those whose pawns the
    /// moved library listed by product only (R2.16), in the background with progress; the summary only tells of
    /// failures.
    private func readAgainAtLaunch() {
        guard let library, library.hasFilesToReadAgain else { return }
        // The files are in Scrollkeeper's folder, readable while its access is held, until the app quits.
        _ = ScrollkeeperFolder().open()
        let files = library.filesToReadAgain
        guard !files.isEmpty else { return }
        Task { await runImports(files, isReadingAgain: true) }
    }

    var isImporting: Bool { importProgress != nil }

    func pawn(id: UUID) -> Pawn? { library?.pawn(id: id) }

    /// The sheet with its pawns' current IDs and labels (`PawnLibrary.labeled`).
    func labeled(_ sheet: PawnSheet) -> PawnSheet { library?.labeled(sheet) ?? sheet }

    /// Pawns waiting for a name; observed through `pawns`.
    var pawnsNeedingNames: [Pawn] { pawns.filter(\.needsName) }

    func search(_ query: PawnQuery) -> [Pawn] { library?.search(query) ?? [] }

    func pawnsNeedingTags(by model: String, visible: Set<UUID>) -> [Pawn] {
        library?.pawnsNeedingTags(by: model, visible: visible) ?? []
    }

    /// Lays out, draws and exports a sheet; nil when the library couldn't be opened.
    func exporter(for sheet: PawnSheet) -> SheetExporter? {
        guard let library, let renderer else { return nil }
        ItemCardPreferences.apply(to: renderer)
        var exporter = SheetExporter(sheet: sheet, library: library, renderer: renderer)
        exporter.catalog = catalog
        return exporter
    }

    func sourceTitle(of pawn: Pawn) -> String { library?.sourceTitle(of: pawn) ?? "" }

    func shortSourceTitle(of pawn: Pawn) -> String { library?.shortSourceTitle(of: pawn) ?? "" }

    func sourceTitles(of pawn: Pawn) -> [String] { library?.sourceTitles(of: pawn) ?? [] }

    // MARK: Importing

    /// What Import PDF… asks for.
    static let importPrompt = "Choose Paizo pawn, token, Battle Cards or item deck PDFs, or the folder of an item "
        + "deck sold as pictures, to add to the library."

    /// Imports every pawn, token, Battle Cards and item deck Scrollkeeper downloaded that isn't in the library yet.
    func importFromScrollkeeper() {
        guard let folder = ScrollkeeperFolder().open() else {
            askForScrollkeeperFolder()
            return
        }
        importScrollkeeperDownloads(in: folder)
    }

    /// Remembers the folder the user picked for Scrollkeeper's downloads and imports from it. Access to a folder
    /// chosen on the iPad is held until the app quits, as for a remembered folder (`ScrollkeeperFolder.open()`):
    /// its files are readable only while it is.
    func useScrollkeeperFolder(_ folder: URL) {
        _ = folder.startAccessingSecurityScopedResource()
        do {
            try ScrollkeeperFolder().remember(folder)
        } catch {
            errorMessage = "Remembering Scrollkeeper's folder failed: \(error.localizedDescription)"
        }
        importScrollkeeperDownloads(in: folder)
    }

    private func importScrollkeeperDownloads(in folder: URL) {
        let files = ScrollkeeperScanner.artFiles(in: folder)
        guard !files.isEmpty else {
            let place = FolderName(url: folder)
            importSummary = "No pawn, token, Battle Cards or item deck PDFs were found in Scrollkeeper's downloads "
                + "(\(place.title) · \(place.location))."
            return
        }
        importPDFs(files)
    }

    /// Imports PDFs one at a time, reading each off the main thread. Files and folders chosen on the iPad are
    /// readable only while their access is held, so it is held until the imports are done.
    func importPDFs(_ urls: [URL]) {
        guard !isImporting, let library else { return }
        let accessed = urls.filter { $0.startAccessingSecurityScopedResource() }
        let pending = PawnLibrary.importableFiles(urls).filter { !library.hasImported($0) }
        guard !pending.isEmpty else {
            accessed.forEach { $0.stopAccessingSecurityScopedResource() }
            importSummary = urls.count == 1 ? "That PDF is already in the library."
                                            : "Those PDFs are already in the library."
            return
        }
        Task {
            await runImports(pending)
            accessed.forEach { $0.stopAccessingSecurityScopedResource() }
        }
    }

    private func runImports(_ urls: [URL], isReadingAgain: Bool = false) async {
        var reports: [ImportReport] = []
        var failures: [String] = []
        for (index, url) in urls.enumerated() {
            importProgress = ImportProgress(fileName: url.lastPathComponent, done: index, total: urls.count)
            do {
                let prepared = try await Task.detached { try PawnLibrary.prepareImport(of: url) }.value
                let report = try isReadingAgain ? library?.commitReadAgain(prepared) : library?.commit(prepared)
                if let report { reports.append(report) }
            } catch {
                failures.append("\(url.lastPathComponent): \(error)")
            }
            refresh()
        }
        importProgress = nil
        if isReadingAgain {
            if !failures.isEmpty { importSummary = "Could not read again: \(failures.joined(separator: "; "))." }
        } else {
            importSummary = Self.summary(of: reports, failures: failures)
        }
        PawnTaggingModel.shared.tagNewPawns()
    }

    // MARK: Editing

    func rename(_ id: UUID, to name: String) {
        perform { try $0.rename(id, to: name) }
    }

    func correctTags(_ tags: [String], of id: UUID) {
        perform { try $0.correctTags(tags, of: id) }
    }

    func remove(_ ids: Set<UUID>) {
        let removed = ids.compactMap { library?.pawn(id: $0) }
        perform { try $0.remove(ids) }
        removed.forEach { backgroundRenderer?.forget($0) }
    }

    /// The question to ask before removing pawns; nil when removing them deletes nothing (R2.5).
    func removalWarning(for ids: Set<UUID>) -> RemovalWarning? {
        library?.removalWarning(for: ids)
    }

    /// Adds a pawn made from the user's art; nil when it could not be saved.
    func addCustomPawn(_ new: NewCustomPawn) -> Pawn? {
        var pawn: Pawn?
        perform { pawn = try $0.addCustomPawn(new) }
        PawnTaggingModel.shared.tagNewPawns()
        return pawn
    }

    /// Records a pawn's tags; `saveTags()` saves them.
    func setTags(_ tags: [String], by model: String, of id: UUID) {
        library?.setTags(tags, by: model, of: id)
        refresh()
    }

    /// Records the name the model suggests for a pawn needing one; `saveTags()` saves it.
    func setSuggestedName(_ name: String, of id: UUID) {
        library?.setSuggestedName(name, of: id)
        refresh()
    }

    func saveTags() {
        perform { try $0.save() }
    }

    private func perform(_ change: (PawnLibrary) throws -> Void) {
        guard let library else { return }
        do {
            try change(library)
        } catch {
            errorMessage = "\(error)"
        }
        refresh()
        tellSyncOfCustomPawnChanges()
    }

    func refresh() {
        pawns = library?.pawns ?? []
        itemArt = library?.itemArt ?? []
        sources = library?.sources.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } ?? []
    }
}
