import AppKit
import PawnShopCore
import PDFKit
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
    let hasPawns: Bool
}

extension FocusedValues {
    @Entry var sheetActions: SheetActions?
}

/// Page Setup, Print and Export for a sheet.
@MainActor
enum SheetOutput {
    /// Shows Page Setup for the sheet's paper and stores the result in the sheet.
    static func runPageSetup(for sheet: inout PawnSheet) {
        let info = printInfo(for: sheet.settings.paper)
        guard NSPageLayout().runModal(with: info) == NSApplication.ModalResponse.OK.rawValue else { return }
        let imageable = info.imageablePageBounds
        guard info.paperSize.width > 0, imageable.width > 0 else { return }
        sheet.settings.paper = PaperSetup(paperSize: info.paperSize, imageableRect: imageable)
    }

    /// Writes or prints the sheet as laid out, at 100% scale.
    static func perform(_ kind: OutputKind, sheet: PawnSheet, title: String, library: LibraryModel) {
        guard let pawnLibrary = library.library, let renderer = library.renderer else { return }
        let data = SheetExporter(sheet: sheet, library: pawnLibrary, renderer: renderer).pdfData()
        switch kind {
        case .export: export(data, suggestedName: title)
        case .print: print(data, title: title, paper: sheet.settings.paper)
        }
    }

    private static func export(_ data: Data, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(suggestedName).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            let reason = error.localizedDescription
            LibraryModel.shared.errorMessage = "Exporting \(url.lastPathComponent) failed: \(reason)"
        }
    }

    /// Prints exactly as laid out: no scaling, rotation or extra margins.
    private static func print(_ data: Data, title: String, paper: PaperSetup) {
        guard let document = PDFDocument(data: data) else { return }
        let info = printInfo(for: paper)
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        guard let operation = document.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false)
        else { return }
        operation.jobTitle = title
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    private static func printInfo(for paper: PaperSetup) -> NSPrintInfo {
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.paperSize = paper.paperSize
        return info
    }
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
                    dismiss()
                    perform(settings)
                }
            }
        }
    }
}

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
