#if os(iOS)
import AppNotices
import PawnShopCore
import SwiftUI

/// The iPad and iPhone app: sheets are documents in the system's document browser, as on the Mac, sharing one
/// pawn library.
public struct PawnShopApp: App {
    @State private var library = LibraryModel.shared
    @Environment(\.scenePhase) private var scenePhase

    public init() {
        PawnTaggingModel.shared.tagNewPawns()
    }

    public var body: some Scene {
        DocumentGroup(newDocument: PawnSheetDocument()) { file in
            SheetWindow(document: file.$document, fileURL: file.fileURL)
                .environment(library)
        }
        .commands {
            LibraryCommands(library: library)
            AboutCommands(info: .pawnShop)
        }
        // A suspended app holding the shared library's file open is ended by the system (shared libraries R5.4);
        // back in the foreground, it reads what other apps changed meanwhile.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: library.close()
            case .active: library.open()
            default: break
            }
        }

        AboutWindow(info: .pawnShop)
    }
}

/// The Library menu, as a toolbar button: the iPad shows no menu bar without a keyboard.
struct LibraryMenu: View {
    let actions: SheetActions
    let showSettings: () -> Void
    @Environment(LibraryModel.self) private var library
    private let tagging = PawnTaggingModel.shared

    var body: some View {
        Menu {
            Button("Import PDF…", systemImage: "doc.badge.plus") { library.chooseAndImportPDFs() }
            Button("Import from Scrollkeeper", systemImage: "books.vertical") { library.importFromScrollkeeper() }
            Button("Tag New Pawns", systemImage: "tag") { tagging.tagNewPawnsReportingProblems() }
                .disabled(!tagging.isOn || tagging.isRunning)
            Divider()
            Button("Review Unnamed Pawns…", systemImage: "questionmark.square") { actions.reviewNames() }
                .disabled(library.pawnsNeedingNames.isEmpty)
            Button("Add Custom Pawn…", systemImage: "plus.square") { actions.addCustomPawn() }
            Button("Export PDF…", systemImage: "square.and.arrow.up") { actions.output(.export) }
                .disabled(!actions.hasPawns)
            Divider()
            Button("Settings…", systemImage: "gear", action: showSettings)
        } label: {
            Label("Library", systemImage: "books.vertical")
        }
    }
}

extension View {
    /// The file browsers the library asks for on the iPad: pawn PDFs to import, and Scrollkeeper's folder.
    func libraryImporters() -> some View {
        modifier(LibraryImporters())
    }
}

private struct LibraryImporters: ViewModifier {
    @Environment(LibraryModel.self) private var library

    func body(content: Content) -> some View {
        @Bindable var library = library
        content
            .fileImporter(isPresented: $library.isChoosingPDFs, allowedContentTypes: [.pdf, .jpeg, .folder],
                          allowsMultipleSelection: true) { result in
                if case let .success(urls) = result { library.importPDFs(urls) }
            }
            .fileDialogMessage(LibraryModel.importPrompt)
            // Two file importers on one view: only the last one shows, so this one sits on a view of its own.
            .background {
                Color.clear
                    .fileImporter(isPresented: $library.isChoosingScrollkeeperFolder,
                                  allowedContentTypes: [.folder]) { result in
                        if case let .success(folder) = result { library.useScrollkeeperFolder(folder) }
                    }
                    .fileDialogMessage("Choose Scrollkeeper's downloads folder so Pawn Shop can import from it.")
            }
    }
}

/// What the Mac keeps in Settings, with the About screen, in a sheet.
struct PadSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Tagging") { TaggingSettingsView(tagging: .shared).navigationTitle("Tagging") }
                NavigationLink("Item Cards") { ItemCardSettingsView().navigationTitle("Item Cards") }
                NavigationLink("Sync") { SyncSettingsView().navigationTitle("Sync") }
                NavigationLink("About Pawn Shop") { ScrollView { AboutView(info: .pawnShop) }.navigationTitle("About") }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
#endif
