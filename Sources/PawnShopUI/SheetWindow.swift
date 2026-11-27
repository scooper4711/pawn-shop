import PawnShopCore
import SwiftUI

/// A sheet's window: the library on the left, the pages in the middle, the sheet's pawns on the right.
struct SheetWindow: View {
    @Binding var document: PawnSheetDocument
    let fileURL: URL?
    @Environment(LibraryModel.self) private var library
    @State private var selectedEntry: UUID?
    @State private var showsInspector = true
    @State private var outputRequest: OutputKind?
    /// The export or print chosen in the options sheet, run once that sheet has closed.
    @State private var pendingOutput: PendingOutput?
    @State private var addingCustomPawn = false
    @State private var reviewingNames = false
    @State private var previewedPawn: UUID?
    @State private var previewedItem: String?
    /// The rendered sheet waiting for the user to choose where to save it.
    @State private var exportedPDF: SheetPDF?
    @State private var showsSettings = false
    /// Whether the library pane lists pawns, items or spells.
    @AppStorage("libraryPane") private var pane = LibraryPane.pawns
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var widthClass
    @State private var compactTab = CompactTab.browse
    #endif

    var body: some View {
        layout
        #if os(iOS)
        // An iPad in portrait has no room for three columns: the inspector would cover the page, so it shows only
        // in a wide window, as in landscape, and opens from the toolbar otherwise.
        .onGeometryChange(for: Bool.self) { $0.size.width >= Self.widthForInspector } action: { isWide in
            showsInspector = isWide
        }
        #endif
        .overlay(alignment: .bottom) { ImportStatusBanner() }
        .overlay {
            if let pawn = previewedPawn.flatMap(library.pawn(id:)) {
                PawnPreview(pawn: pawn) { previewedPawn = nil }
            } else if let item = previewedItem.flatMap(library.catalog.item(id:)) {
                ItemPreview(card: library.card(for: item)) { previewedItem = nil }
            }
        }
        .focusedSceneValue(\.sheetActions, actions)
        // Saved sheets name the pawns they print, so a device without one can say which is missing.
        .onChange(of: document.sheet.entries, initial: true) { relabel() }
        // A device without a pawn's PDF asks iCloud for its picture (R10.4), and keeps asking while the sheet is
        // open: no device may have uploaded it yet.
        .task(id: document.sheet.entries) { await library.keepShowingPictures(of: document.sheet) }
        .keepsSheetPreviews(of: document)
        // The print panel opens on the sheet's window once the options sheet is gone: started from the closing
        // options sheet, it never showed and the job printed at once with the printer's defaults.
        .sheet(item: $outputRequest, onDismiss: performPendingOutput) { kind in
            OutputOptionsView(kind: kind, settings: document.sheet.settings) { settings in
                var sheet = document.sheet
                sheet.settings = settings
                pendingOutput = PendingOutput(kind: kind, sheet: sheet)
            }
        }
        .fileExporter(isPresented: isExporting, document: exportedPDF, contentType: .pdf,
                      defaultFilename: exportedPDF?.name) { result in
            if case let .failure(error) = result {
                library.errorMessage = "Exporting failed: \(error.localizedDescription)"
            }
        }
        #if os(iOS)
        .libraryImporters()
        .sheet(isPresented: $showsSettings) { PadSettingsView() }
        #endif
        .sheet(isPresented: $reviewingNames) { ReviewNamesView() }
        .sheet(isPresented: $addingCustomPawn) {
            AddCustomPawnView { document.sheet.add($0.id) }
        }
        // Only file URLs: a dropDestination for URL would also take the library's drags, as a URL made from their
        // data, before the sheet preview could.
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            DroppedFiles.load(from: providers) { urls in
                let files = urls.filter(PawnLibrary.isImportable)
                if !files.isEmpty { library.importPDFs(files) }
            }
            return true
        }
        .alert("Import Finished", isPresented: summaryShown) {
            Button("OK") { library.importSummary = nil }
        } message: {
            Text(library.importSummary ?? "")
        }
        .alert("Something Went Wrong", isPresented: errorShown) {
            Button("OK") { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    /// Three columns, or on a narrow screen (an iPhone, an iPad's slim window) the same three as tabs: columns
    /// there fold down to the library alone, with no way to the pages, the inspector or the toolbar.
    @ViewBuilder private var layout: some View {
        #if os(iOS)
        if widthClass == .compact { tabs } else { columns }
        #else
        columns
        #endif
    }

    private var columns: some View {
        NavigationSplitView {
            libraryPane
                .navigationSplitViewColumnWidth(min: 280, ideal: 360, max: 600)
        } detail: {
            pages
                .inspector(isPresented: $showsInspector) {
                    inspector
                        .inspectorColumnWidth(min: Self.inspectorWidth.min, ideal: Self.inspectorWidth.ideal)
                }
                .toolbar {
                    ToolbarItemGroup {
                        printButton
                        Button { showsInspector.toggle() } label: { Label("Sheet", systemImage: "sidebar.right") }
                            .help("Show or hide the sheet's pawns")
                    }
                    #if os(iOS)
                    ToolbarItemGroup(placement: .topBarLeading) { libraryMenu }
                    #endif
                }
        }
    }

    #if os(iOS)
    private var tabs: some View {
        TabView(selection: $compactTab) {
            Tab("Browse", systemImage: "square.grid.2x2", value: CompactTab.browse) { libraryPane }
            Tab("Pages", systemImage: "doc", value: CompactTab.pages) { pages }
            // The badge counts the copies, so adding one shows without leaving the library.
            Tab("Sheet", systemImage: "list.bullet", value: CompactTab.sheet) { inspector }
                .badge(document.sheet.copyCount)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { libraryMenu }
            ToolbarItem(placement: .primaryAction) { printButton }
        }
    }

    private var libraryMenu: some View {
        LibraryMenu(actions: actions) { showsSettings = true }
    }
    #endif

    private var libraryPane: some View {
        VStack(spacing: 0) {
            Picker("Library", selection: $pane) {
                Text("Pawns").tag(LibraryPane.pawns)
                Text("Items").tag(LibraryPane.items)
                Text("Spells").tag(LibraryPane.spells)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 8)
            switch pane {
            case .pawns:
                LibraryBrowser(sheet: $document.sheet, preview: $previewedPawn) { reviewingNames = true }
            case .items:
                ItemBrowser(sheet: $document.sheet, preview: $previewedItem, pane: .items)
                    .id(LibraryPane.items)
            case .spells:
                ItemBrowser(sheet: $document.sheet, preview: $previewedItem, pane: .spells)
                    .id(LibraryPane.spells)
            }
        }
    }

    private var pages: some View {
        SheetPreview(sheet: $document.sheet, selectedEntry: $selectedEntry)
            .dropDestination(for: DraggedContent.self) { dropped, _ in
                dropped.forEach { document.sheet.add($0.contents, copies: $0.copies) }
                return !dropped.isEmpty
            }
    }

    private var inspector: some View {
        SheetInspector(sheet: $document.sheet, selectedEntry: $selectedEntry, pageCount: pageCount,
                       isFromNewerReader: document.isFromNewerReader)
    }

    private var printButton: some View {
        Button { outputRequest = .print } label: { Label("Print", systemImage: "printer") }
            .help("Print the sheet")
            .disabled(document.sheet.entries.isEmpty)
    }

    #if os(iOS)
    static let widthForInspector: CGFloat = 1100
    /// Wider than on the Mac: the iPad's steppers and buttons are larger, and a narrower column cuts names short.
    static let inspectorWidth: (min: CGFloat, ideal: CGFloat) = (300, 340)
    #else
    static let inspectorWidth: (min: CGFloat, ideal: CGFloat) = (240, 280)
    #endif

    /// Writes or prints the sheet as laid out, at 100% scale, once the pictures it lacks have come from iCloud
    /// or have stopped coming (R10.4).
    private func performPendingOutput() {
        guard let output = pendingOutput else { return }
        pendingOutput = nil
        Task {
            await library.waitForPictures(of: output.sheet)
            guard let data = library.exporter(for: output.sheet)?.pdfData() else { return }
            switch output.kind {
            case .export: exportedPDF = SheetPDF(data: data, name: title)
            case .print: SheetOutput.print(data, title: title, paper: output.sheet.settings.paper)
            }
        }
    }

    private var isExporting: Binding<Bool> {
        Binding(get: { exportedPDF != nil }, set: { if !$0 { exportedPDF = nil } })
    }

    private var actions: SheetActions {
        SheetActions(pageSetup: pageSetup,
                     output: { outputRequest = $0 },
                     addCustomPawn: { addingCustomPawn = true },
                     reviewNames: { reviewingNames = true },
                     hasPawns: !document.sheet.entries.isEmpty)
    }

    /// Updates the sheet's pawn IDs and labels; an unchanged sheet isn't touched, so it isn't marked as edited.
    private func relabel() {
        let labeled = library.labeled(document.sheet)
        if labeled != document.sheet { document.sheet = labeled }
    }

    private func pageSetup() {
        #if os(macOS)
        SheetOutput.runPageSetup(for: &document.sheet)
        #endif
    }

    private var title: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? "Pawns"
    }

    private var pageCount: Int {
        _ = library.pawns
        return library.exporter(for: document.sheet)?.layout().pages.count ?? 0
    }

    private var summaryShown: Binding<Bool> {
        Binding(get: { library.importSummary != nil }, set: { if !$0 { library.importSummary = nil } })
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })
    }
}

/// Shows which PDF is being imported, or that an export or a print waits for pictures from iCloud.
struct ImportStatusBanner: View {
    @Environment(LibraryModel.self) private var library

    var body: some View {
        if library.isWaitingForPictures {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Getting pictures from iCloud…")
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding()
        } else if let progress = library.importProgress {
            VStack(alignment: .leading, spacing: 4) {
                Text("Importing \(progress.fileName)").lineLimit(1)
                ProgressView(value: Double(progress.done), total: Double(progress.total))
                Text("\(progress.done) of \(progress.total) PDFs").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding()
        }
    }
}

#if os(iOS)
/// The tabs a narrow screen shows in place of the columns.
enum CompactTab {
    case browse, pages, sheet
}
#endif

/// What the library pane lists.
enum LibraryPane: String {
    case pawns, items, spells
}
