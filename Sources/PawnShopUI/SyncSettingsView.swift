import SwiftUI
import TablesideSyncUI

/// The Settings tab for syncing (R10.5 to R10.7): what syncs, then the toolkit's sync settings (whether the library
/// syncs through iCloud, how many downloaded pictures this device keeps, and how much room they take).
struct SyncSettingsView: View {
    @Environment(LibraryModel.self) private var library

    /// What the library syncs, for the top of the pane.
    static let explanation = "Your pawns, their names and keywords, and your custom pawns are kept the same on your "
        + "devices through your own iCloud. The PDFs stay on the device that imported them: a device without a "
        + "pawn's PDF draws the pawn from a picture, downloaded when the pawn is first shown."

    var body: some View {
        @Bindable var library = library
        Form {
            note(Self.explanation)
            SyncSettingsSection(app: .pawnShop, sync: library.syncs ? library.sync : nil,
                                picturesChanged: $library.picturesFetched)
            if let problem = library.syncProblem { note(problem) }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 460)
        #endif
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
