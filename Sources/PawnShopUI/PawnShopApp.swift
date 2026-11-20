#if os(macOS)
import AppNotices
import PawnShopCore
import SwiftUI

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
        DocumentGroup(newDocument: PawnSheetDocument()) { file in
            SheetWindow(document: file.$document, fileURL: file.fileURL)
                .environment(library)
                // Wide enough for the library and inspector at their ideal widths plus the page; any narrower and
                // the split view clips both side columns instead of shrinking their contents.
                .frame(minWidth: 1100, minHeight: 600)
        }
        .commands {
            AboutCommands(info: .pawnShop)
            #if !APP_STORE
            UpdateCommands(updater: .shared)
            #endif
            PrivacyCommands()
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
}

/// The privacy policy, in the Help menu.
struct PrivacyCommands: Commands {
    // A literal URL that is known to parse.
    // swiftlint:disable:next force_unwrapping
    private static let policy = URL(string: "https://github.com/scooper4711/pawn-shop/blob/main/PRIVACY.md")!

    var body: some Commands {
        CommandGroup(after: .help) {
            Link("Pawn Shop Privacy Policy", destination: Self.policy)
        }
    }
}

#endif
