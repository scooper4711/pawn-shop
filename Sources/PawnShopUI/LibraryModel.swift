import Foundation
import Observation
import PawnShopCore
import TablesideShared

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

    @ObservationIgnored private(set) var library: PawnLibrary?
    @ObservationIgnored private(set) var renderer: PawnRenderer?
    @ObservationIgnored private(set) var backgroundRenderer: BackgroundRenderer?
    /// Hears of other apps' changes to the shared library (R2.1).
    @ObservationIgnored private var changeObserver: LibraryChangeObserver?
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
    func libraryChanged() {
        do {
            if try library?.refresh() == true { refresh() }
        } catch {
            errorMessage = "Reading the shared library failed: \(error)"
        }
    }

    /// Lets go of the shared library's file as the app goes to the background on the iPad.
    func close() { library?.close() }

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

    func searchItems(_ query: ItemQuery) -> [CatalogItem] { catalog.search(query) }

    /// How many cards the item's or spell's text takes (R8.3.1).
    func cardCount(for item: CatalogItem) -> Int {
        guard let renderer else { return 1 }
        ItemCardPreferences.apply(to: renderer)
        return renderer.cardCount(for: item)
    }

    /// An item's card, with the art an imported item deck prints for it.
    func card(for item: CatalogItem) -> ItemCardContent {
        ItemCardContent(item: item, artwork: ItemArtMatcher(artwork: itemArt, renames: catalog.renames)
            .artwork(for: item))
    }

    /// A card to show the art setting on: the first item an imported deck has art for, or else the first
    /// consumable; nil without a catalog.
    var sampleCard: ItemCardContent? {
        let matcher = ItemArtMatcher(artwork: itemArt, renames: catalog.renames)
        let item = catalog.items.first { matcher.artwork(for: $0) != nil }
            ?? catalog.items.first { $0.kind == .consumable }
        return item.map(card(for:))
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

    func add(_ pawn: Pawn) {
        perform { try $0.add(pawn) }
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
    }

    private func refresh() {
        pawns = library?.pawns ?? []
        itemArt = library?.itemArt ?? []
        sources = library?.sources.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } ?? []
    }
}
