#if os(macOS)
import AppNotices
import PawnShopCore
import SwiftUI
import TablesideShared

/// The Mac app: a window per sheet, the Library menu and Settings.
public struct PawnShopApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var library = LibraryModel.shared

    public init() {
        WindowSnapshots.scheduleIfRequested()
        DocumentsFolder.prepareInBackground()
        PawnTaggingModel.shared.tagNewPawns()
    }

    public var body: some Scene {
        // A sheet another app asked for is parked until its document is made (`IncomingSheets`, R13).
        DocumentGroup(newDocument: IncomingSheets.newDocument()) { file in
            SheetWindow(document: file.$document, fileURL: file.fileURL)
                .environment(library)
                .requestedTitle(file.fileURL == nil ? file.document.requestedTitle : nil)
                // Wide enough for the library and inspector at their ideal widths plus the page; any narrower and
                // the split view clips both side columns instead of shrinking their contents.
                .frame(minWidth: 1100, minHeight: 600)
        }
        .commands {
            AboutCommands(info: .pawnShop)
            #if !APP_STORE
            UpdateCommands(updater: .shared)
            #endif
            HelpLinkCommands()
            SheetFileCommands()
            LibraryCommands(library: library)
        }

        Settings {
            TabView {
                #if !APP_STORE
                UpdateSettingsView(updater: .shared)
                    .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
                #endif
                TaggingSettingsView(tagging: .shared)
                    .tabItem { Label("Tagging", systemImage: "tag") }
                ItemCardSettingsView()
                    .environment(library)
                    .tabItem { Label("Item Cards", systemImage: "rectangle.portrait.on.rectangle.portrait") }
                SyncSettingsView()
                    .environment(library)
                    .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath.icloud") }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        #if !APP_STORE
        Task { await UpdateAlerts.checkAtLaunch(.shared) }
        #endif
    }

    /// The links other Tableside Toolkit apps send, whether or not the app was running.
    func application(_: NSApplication, open urls: [URL]) {
        urls.filter { $0.scheme?.lowercased() == PawnSheetRequest.scheme }.forEach { IncomingSheets.open($0) }
    }
}

/// The pawn bases and the privacy policy, in the Help menu.
struct HelpLinkCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .help) {
            Link("3D-Printable Pawn Bases", destination: HelpLinks.pawnBases)
            Link("Pawn Shop Privacy Policy", destination: HelpLinks.privacyPolicy)
        }
    }
}

#endif
