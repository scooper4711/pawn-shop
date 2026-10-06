import PawnShopCore
import SwiftUI

@main
struct PawnShopApp: App {
    @State private var library = LibraryModel.shared

    init() {
        WindowSnapshots.scheduleIfRequested()
        PawnTaggingModel.shared.tagNewPawns()
    }

    var body: some Scene {
        DocumentGroup(newDocument: PawnSheetDocument()) { file in
            SheetWindow(document: file.$document, fileURL: file.fileURL)
                .environment(library)
                // Wide enough for the library and inspector at their ideal widths plus the page; any narrower and
                // the split view clips both side columns instead of shrinking their contents.
                .frame(minWidth: 1100, minHeight: 600)
        }
        .commands {
            SheetFileCommands()
            LibraryCommands(library: library)
        }
    }
}

/// The Library menu.
struct LibraryCommands: Commands {
    let library: LibraryModel
    @FocusedValue(\.sheetActions) private var actions

    var body: some Commands {
        CommandMenu("Library") {
            Button("Import PDF…") { library.chooseAndImportPDFs() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Import from Scrollkeeper") { library.importFromScrollkeeper() }
            Button("Tag New Pawns") { PawnTaggingModel.shared.tagNewPawnsReportingProblems() }
                .disabled(PawnTaggingModel.shared.progress != nil)
            Divider()
            Button("Review Unnamed Pawns…") { actions?.reviewNames() }
                .disabled(actions == nil || library.pawnsNeedingNames.isEmpty)
            Button("Add Custom Pawn…") { actions?.addCustomPawn() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(actions == nil)
        }
    }
}
