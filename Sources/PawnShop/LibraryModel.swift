import AppKit
import Observation
import PawnShopCore

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
    private(set) var importProgress: ImportProgress?
    /// The outcome of the last import batch, shown until dismissed.
    var importSummary: String?
    var errorMessage: String?

    @ObservationIgnored private(set) var library: PawnLibrary?
    @ObservationIgnored private(set) var renderer: PawnRenderer?
    @ObservationIgnored private(set) var backgroundRenderer: BackgroundRenderer?

    private init() {
        do {
            let library = try PawnLibrary(folder: Self.libraryFolder)
            self.library = library
            renderer = PawnRenderer(library: library)
            backgroundRenderer = BackgroundRenderer(folders: library.folders)
            refresh()
        } catch {
            errorMessage = "Opening the pawn library failed: \(error)"
        }
    }

    /// The library folder; `PAWN_SHOP_LIBRARY` points the app at another one, for trying things out.
    static var libraryFolder: URL {
        ProcessInfo.processInfo.environment["PAWN_SHOP_LIBRARY"].map { URL(fileURLWithPath: $0) }
            ?? PawnLibrary.defaultFolder
    }

    var isImporting: Bool { importProgress != nil }

    func pawn(id: UUID) -> Pawn? { library?.pawn(id: id) }

    func search(_ query: PawnQuery) -> [Pawn] { library?.search(query) ?? [] }

    func sourceTitle(of pawn: Pawn) -> String { library?.sourceTitle(of: pawn) ?? "" }

    func shortSourceTitle(of pawn: Pawn) -> String { library?.shortSourceTitle(of: pawn) ?? "" }

    func sourceTitles(of pawn: Pawn) -> [String] { library?.sourceTitles(of: pawn) ?? [] }

    // MARK: Importing

    /// Asks for pawn PDFs and imports them.
    func chooseAndImportPDFs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.message = "Choose Paizo pawn PDFs to add to the library."
        guard panel.runModal() == .OK else { return }
        importPDFs(panel.urls)
    }

    /// Imports every pawn PDF Scrollkeeper downloaded that isn't in the library yet.
    func importFromScrollkeeper() {
        let files = ScrollkeeperScanner.pawnPDFs()
        guard !files.isEmpty else {
            importSummary = "No pawn PDFs were found in Scrollkeeper's downloads "
                + "(\(ScrollkeeperScanner.defaultFolder.path))."
            return
        }
        importPDFs(files)
    }

    /// Imports PDFs one at a time, reading each off the main thread.
    func importPDFs(_ urls: [URL]) {
        guard !isImporting, let library else { return }
        let pending = urls.filter { !library.hasImported($0) }
        guard !pending.isEmpty else {
            importSummary = urls.count == 1 ? "That PDF is already in the library."
                                            : "Those PDFs are already in the library."
            return
        }
        Task { await runImports(pending) }
    }

    private func runImports(_ urls: [URL]) async {
        var reports: [ImportReport] = []
        var failures: [String] = []
        for (index, url) in urls.enumerated() {
            importProgress = ImportProgress(fileName: url.lastPathComponent, done: index, total: urls.count)
            do {
                let prepared = try await Task.detached { try PawnLibrary.prepareImport(of: url) }.value
                if let report = try library?.commit(prepared) { reports.append(report) }
            } catch {
                failures.append("\(url.lastPathComponent): \(error)")
            }
            refresh()
        }
        importProgress = nil
        importSummary = Self.summary(of: reports, failures: failures)
    }

    static func summary(of reports: [ImportReport], failures: [String]) -> String {
        let added = reports.reduce(0) { $0 + $1.added }
        let known = reports.reduce(0) { $0 + $1.alreadyKnown }
        let unnamed = reports.reduce(0) { $0 + $1.unnamed.count }
        let empty = reports.filter { $0.added + $0.alreadyKnown == 0 }.map(\.sourceTitle)
        var lines = ["Added \(added) pawns from \(reports.count) PDF\(reports.count == 1 ? "" : "s")."]
        if known > 0 { lines.append("\(known) were already in the library from other products.") }
        if unnamed > 0 { lines.append("\(unnamed) outlines had no name printed; they are listed as \"Unnamed\".") }
        if !empty.isEmpty { lines.append("No pawns were found in: \(empty.joined(separator: ", ")).") }
        if !failures.isEmpty { lines.append("Could not import: \(failures.joined(separator: "; ")).") }
        return lines.joined(separator: "\n")
    }

    // MARK: Editing

    func rename(_ id: UUID, to name: String) {
        perform { try $0.rename(id, to: name) }
    }

    func remove(_ ids: Set<UUID>) {
        perform { try $0.remove(ids) }
        ids.forEach { backgroundRenderer?.forget($0) }
    }

    func add(_ pawn: Pawn) {
        perform { try $0.add(pawn) }
    }

    /// Adds a pawn made from the user's art; nil when it could not be saved.
    func addCustomPawn(_ new: NewCustomPawn) -> Pawn? {
        var pawn: Pawn?
        perform { pawn = try $0.addCustomPawn(new) }
        return pawn
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
        sources = library?.sources.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } ?? []
    }
}
