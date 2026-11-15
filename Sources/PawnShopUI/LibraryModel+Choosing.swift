import Foundation
import PawnShopCore

#if os(macOS)
import AppKit

extension LibraryModel {
    /// Asks for pawn PDFs and imports them.
    func chooseAndImportPDFs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .jpeg]
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = Self.importPrompt
        guard panel.runModal() == .OK else { return }
        importPDFs(panel.urls)
    }

    /// In the App Sandbox Pawn Shop may only read folders the user picks, so it asks once for Scrollkeeper's.
    func askForScrollkeeperFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = ScrollkeeperFolder().suggestedLocation
        panel.prompt = "Use Folder"
        panel.message = "Choose Scrollkeeper's downloads folder so Pawn Shop can import from it. "
            + "You'll only be asked once."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        useScrollkeeperFolder(folder)
    }
}

#else

extension LibraryModel {
    /// Shows the file browser for pawn PDFs (`LibraryImporters` imports what is chosen).
    func chooseAndImportPDFs() {
        isChoosingPDFs = true
    }

    /// Without Scrollkeeper's App Group (no Scrollkeeper on this iPad, or one that keeps its downloads elsewhere),
    /// asks once for the folder in Files.
    func askForScrollkeeperFolder() {
        isChoosingScrollkeeperFolder = true
    }
}
#endif
