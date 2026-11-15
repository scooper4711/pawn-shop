import PawnShopCore
import SwiftUI

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
                .disabled(!PawnTaggingModel.shared.isOn || PawnTaggingModel.shared.isRunning)
            Divider()
            Button("Review Unnamed Pawns…") { actions?.reviewNames() }
                .disabled(actions == nil || library.pawnsNeedingNames.isEmpty)
            Button("Add Custom Pawn…") { actions?.addCustomPawn() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(actions == nil)
        }
    }
}
