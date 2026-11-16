import PawnShopCore
import SwiftUI
import UniformTypeIdentifiers

/// Export or print.
enum OutputKind: String, Identifiable {
    case export, print

    var id: String { rawValue }
    var actionTitle: String { self == .export ? "Export…" : "Print…" }
}

/// The window's File-menu actions, published to the menu bar for the frontmost window.
struct SheetActions {
    let pageSetup: () -> Void
    let output: (OutputKind) -> Void
    let addCustomPawn: () -> Void
    let reviewNames: () -> Void
    let hasPawns: Bool
}

extension FocusedValues {
    @Entry var sheetActions: SheetActions?
}

/// A sheet rendered for export, for the file exporter.
struct SheetPDF: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    let data: Data
    /// The suggested file name, without the extension.
    let name: String

    init(data: Data, name: String) {
        self.data = data
        self.name = name
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
        name = configuration.file.filename ?? "Pawns"
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// An export or print, with the cut settings chosen for it.
struct PendingOutput {
    let kind: OutputKind
    let sheet: PawnSheet
}

/// Asks how to cut and fold before exporting or printing; the sheet's own settings are the starting point.
struct OutputOptionsView: View {
    let kind: OutputKind
    @State var settings: SheetSettings
    let perform: (SheetSettings) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kind == .export ? "Export as PDF" : "Print").font(.headline)
            CutSettingsForm(settings: $settings)
            Text("Pages print at 100% scale; set the printer to Actual Size if it asks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 340)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(kind.actionTitle) {
                    perform(settings)
                    dismiss()
                }
            }
        }
        .sheetToolbar(title: kind == .export ? "Export as PDF" : "Print")
    }
}

#if os(macOS)
/// File-menu commands for the frontmost sheet.
struct SheetFileCommands: Commands {
    @FocusedValue(\.sheetActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Page Setup…") { actions?.pageSetup() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Button("Export PDF…") { actions?.output(.export) }
                .keyboardShortcut("e")
                .disabled(actions?.hasPawns != true)
            Button("Print…") { actions?.output(.print) }
                .keyboardShortcut("p")
                .disabled(actions?.hasPawns != true)
        }
    }
}
#endif
