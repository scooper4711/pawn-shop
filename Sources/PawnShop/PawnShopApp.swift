import PawnShopCore
import SwiftUI

@main
struct PawnShopApp: App {
    @State private var library = LibraryModel.shared

    init() {
        WindowSnapshots.scheduleIfRequested()
    }

    var body: some Scene {
        DocumentGroup(newDocument: PawnSheetDocument()) { file in
            SheetWindow(document: file.$document, fileURL: file.fileURL)
                .environment(library)
                .frame(minWidth: 960, minHeight: 600)
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

    var body: some Commands {
        CommandMenu("Library") {
            Button("Import PDF…") { library.chooseAndImportPDFs() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Import from Scrollkeeper") { library.importFromScrollkeeper() }
        }
    }
}
