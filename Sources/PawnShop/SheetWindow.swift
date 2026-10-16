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
    @State private var addingCustomPawn = false
    @State private var reviewingNames = false
    @State private var previewedPawn: UUID?
    @State private var previewedItem: String?
    /// Whether the library pane lists pawns, items or spells.
    @AppStorage("libraryPane") private var pane = LibraryPane.pawns

    var body: some View {
        NavigationSplitView {
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
            .navigationSplitViewColumnWidth(min: 280, ideal: 360, max: 600)
        } detail: {
            SheetPreview(sheet: $document.sheet, selectedEntry: $selectedEntry)
                .dropDestination(for: DraggedContent.self) { dropped, _ in
                    dropped.forEach { document.sheet.add($0.contents) }
                    return !dropped.isEmpty
                }
                .inspector(isPresented: $showsInspector) {
                    SheetInspector(sheet: $document.sheet, selectedEntry: $selectedEntry, pageCount: pageCount)
                        .inspectorColumnWidth(min: 240, ideal: 280)
                }
                .toolbar {
                    ToolbarItemGroup {
                        Button { outputRequest = .print } label: { Label("Print", systemImage: "printer") }
                            .help("Print the sheet")
                            .disabled(document.sheet.entries.isEmpty)
                        Button { showsInspector.toggle() } label: { Label("Sheet", systemImage: "sidebar.right") }
                            .help("Show or hide the sheet's pawns")
                    }
                }
        }
        .overlay(alignment: .bottom) { ImportStatusBanner() }
        .overlay {
            if let pawn = previewedPawn.flatMap(library.pawn(id:)) {
                PawnPreview(pawn: pawn) { previewedPawn = nil }
            } else if let item = previewedItem.flatMap(library.catalog.item(id:)) {
                ItemPreview(card: library.card(for: item)) { previewedItem = nil }
            }
        }
        .focusedSceneValue(\.sheetActions, actions)
        .sheet(item: $outputRequest) { kind in
            OutputOptionsView(kind: kind, settings: document.sheet.settings) { settings in
                var sheet = document.sheet
                sheet.settings = settings
                SheetOutput.perform(kind, sheet: sheet, title: title, library: library)
            }
        }
        .sheet(isPresented: $reviewingNames) { ReviewNamesView() }
        .sheet(isPresented: $addingCustomPawn) {
            AddCustomPawnView { document.sheet.add($0.id) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(PawnLibrary.isImportable)
            library.importPDFs(files)
            return !files.isEmpty
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

    private var actions: SheetActions {
        SheetActions(pageSetup: { SheetOutput.runPageSetup(for: &document.sheet) },
                     output: { outputRequest = $0 },
                     addCustomPawn: { addingCustomPawn = true },
                     reviewNames: { reviewingNames = true },
                     hasPawns: !document.sheet.entries.isEmpty)
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

/// Shows which PDF is being imported.
struct ImportStatusBanner: View {
    @Environment(LibraryModel.self) private var library

    var body: some View {
        if let progress = library.importProgress {
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

/// What the library pane lists.
enum LibraryPane: String {
    case pawns, items, spells
}
