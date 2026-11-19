import PawnShopCore
import SwiftUI

/// The Settings tab for syncing (R10.5 to R10.7): whether the library syncs through iCloud, how many downloaded
/// pictures this device keeps, and how much room they take.
struct SyncSettingsView: View {
    @Environment(LibraryModel.self) private var library
    @State private var keeping = PictureKeeping.shown
    /// What the device keeps as last read, to tell the user's choice from the picker being filled in.
    @State private var keptNow = PictureKeeping.shown
    @State private var downloadedBytes = 0

    var body: some View {
        Form {
            note(SyncSettingsText.explanation)
            Text(SyncSettingsText.summary(of: library.syncStatus))
                .fixedSize(horizontal: false, vertical: true)
            if library.syncStatus == .paused {
                Button("Turn Syncing Back On") { Task { await library.resumeSync() } }
            }
            if let problem = library.syncProblem { note(problem) }
            if library.syncs { pictures }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 460)
        #endif
        .task(id: Shown(syncs: library.syncs, picturesFetched: library.picturesFetched)) { await read() }
    }

    @ViewBuilder private var pictures: some View {
        Picker("Keep on this device", selection: $keeping) {
            ForEach(PictureKeeping.choices(including: keeping), id: \.self) { choice in
                Text(choice.title).tag(choice)
            }
        }
        .onChange(of: keeping) { _, chosen in
            guard chosen != keptNow else { return }
            keptNow = chosen
            Task {
                await library.setPictureKeeping(chosen)
                await read()
            }
        }
        note(SyncSettingsText.keepingNote)
        LabeledContent("Downloaded pictures") {
            Text(SyncSettingsText.size(ofBytes: downloadedBytes)).monospacedDigit()
        }
        Button("Remove Downloaded Pictures") {
            Task {
                await library.removeDownloadedPictures()
                await read()
            }
        }
        .disabled(downloadedBytes == 0)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Reads what the device keeps and how much it has downloaded.
    private func read() async {
        if let kept = await library.pictureKeeping() {
            keptNow = kept
            keeping = kept
        }
        downloadedBytes = await library.downloadedPictureBytes()
    }

    /// What the pane shows: read again once syncing starts and when pictures arrive.
    private struct Shown: Hashable {
        let syncs: Bool
        let picturesFetched: Int
    }
}
