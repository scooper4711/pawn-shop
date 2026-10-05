import PawnShopCore
import SwiftUI

/// A sheet's window: the library on the left, the pages in the middle, the sheet's pawns on the right.
struct SheetWindow: View {
    @Binding var document: PawnSheetDocument
    @Environment(LibraryModel.self) private var library
    @State private var selectedEntry: UUID?
    @State private var showsInspector = true

    var body: some View {
        NavigationSplitView {
            LibraryBrowser(sheet: $document.sheet)
                .navigationSplitViewColumnWidth(min: 280, ideal: 360, max: 600)
        } detail: {
            SheetPreview(sheet: $document.sheet, selectedEntry: $selectedEntry)
                .inspector(isPresented: $showsInspector) {
                    SheetInspector(sheet: $document.sheet, selectedEntry: $selectedEntry, pageCount: pageCount)
                        .inspectorColumnWidth(min: 240, ideal: 280)
                }
                .toolbar {
                    ToolbarItem {
                        Button { showsInspector.toggle() } label: { Label("Sheet", systemImage: "sidebar.right") }
                            .help("Show or hide the sheet's pawns")
                    }
                }
        }
        .overlay(alignment: .bottom) { ImportStatusBanner() }
        .dropDestination(for: URL.self) { urls, _ in
            let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
            library.importPDFs(pdfs)
            return !pdfs.isEmpty
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

    private var pageCount: Int {
        guard let pawnLibrary = library.library, let renderer = library.renderer else { return 0 }
        _ = library.pawns
        return SheetExporter(sheet: document.sheet, library: pawnLibrary, renderer: renderer).layout().pages.count
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
