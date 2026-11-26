#if os(macOS)
import AppKit
import TablesideShared

extension PaperSetup {
    /// The paper of a page setup the user confirmed, keeping the setup itself for the next Page Setup and print.
    /// Nil for a setup without a printable page.
    public init?(pageSetup setup: NSPrintInfo) {
        let imageable = setup.imageablePageBounds
        guard setup.paperSize.width > 0, setup.paperSize.height > 0, imageable.width > 0, imageable.height > 0 else {
            return nil
        }
        self.init(paperSize: setup.paperSize, imageableRect: imageable, pageSetup: PageSetupArchive.data(from: setup))
    }

    /// The page setup to start Page Setup and printing from: the one kept with the paper or, for a paper without
    /// one, the app's current setup at the paper's size.
    public func printInfo() -> NSPrintInfo {
        if let pageSetup, let kept = PageSetupArchive.setup(from: pageSetup) { return kept }
        let setup = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        setup.paperSize = paperSize
        return setup
    }
}

/// The paper new sheets start on: the one last confirmed in Page Setup, in any sheet.
public struct SheetPaperDefault {
    private let store: PageSetupStore

    public init(defaults: UserDefaults = .standard) {
        store = PageSetupStore(defaults: defaults)
    }

    /// Nil until a page setup has been confirmed; new sheets then start on US Letter.
    public var startingPaper: PaperSetup? {
        store.savedSetup.flatMap(PaperSetup.init(pageSetup:))
    }

    public func confirm(_ setup: NSPrintInfo) {
        store.save(setup)
    }
}
#endif
