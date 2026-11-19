import Foundation
import PawnShopCore
import SharedLibraries
import TablesideSync

/// Syncing the library between the user's devices (R10): the shared art library through the toolkit's engine,
/// custom pawns in a zone of Pawn Shop's own on it, and the pictures of pawns whose PDFs aren't on this device.
extension LibraryModel {
    /// How long an export or a print waits for pictures while none arrives.
    static let pictureStall: Duration = .seconds(8)

    /// Starts syncing, where the build names the container and the device has an iCloud account (R10.8,
    /// R10.10). A library opened with `PAWN_SHOP_LIBRARY` is for trying things out and never syncs.
    func startSync() {
        guard let library, ProcessInfo.processInfo.environment["PAWN_SHOP_LIBRARY"] == nil else { return }
        let handler = CustomPawnSync(library: library)
        handler.onChange = { [weak self] in self?.customPawnsMerged() }
        let fallback = PawnLibrary.sharedFallback(in: library.folder)
        let pictures = library.folders.pictures
        Task {
            guard let sync = await LibrarySync.start(app: .pawnShop, fallback: fallback, handlers: [handler])
            else { return }
            self.sync = sync
            customPawnSync = handler
            let requests = PictureRequests(pictures: pictures) { await sync.fetchPictures(named: $0) }
            // The model lives as long as the app does, so holding it here keeps nothing alive that would go.
            requests.onArrival = { self.picturesFetched += 1 }
            pictureRequests = requests
            syncs = true
            for await status in await sync.statusUpdates() { syncStatus = status }
        }
    }

    /// Tells syncing the user changed a custom pawn: unlike the shared library's changes, it hears of these from
    /// nobody else.
    func customPawnsChanged() {
        customPawnSync?.customPawnsChanged()
        Task { await sync?.libraryChanged() }
    }

    /// Lets syncing close the shared library after each use while the app is in the background on the iPad, and
    /// keep it open again once it is back.
    func syncClosed(_ isClosed: Bool) {
        customPawnSync?.closesLibraryAfterUse = isClosed
        Task {
            if isClosed {
                await sync?.close()
            } else {
                await sync?.open()
            }
        }
    }

    /// Back in the foreground on the iPad: reads what changed meanwhile, and syncing keeps the library open.
    func open() {
        syncClosed(false)
        libraryChanged()
    }

    // MARK: Pictures

    /// Asks iCloud for the pictures a pawn is drawn from that this device lacks, and notes the rest as shown
    /// (R10.4), for as long as the task showing the pawn runs: a picture no device has uploaded yet is asked for
    /// again every minute. `draw` is called each time some arrive.
    func keepShowingPictures(of pawn: Pawn, whenSomeArrive draw: @MainActor () async -> Void) async {
        guard !pawn.pictureFiles.isEmpty, let pictureRequests else { return }
        await pictureRequests.keepShowing(pawn.pictureFiles, whenSomeArrive: draw)
    }

    /// Asks for every picture a sheet lacks at once, for as long as the task showing the sheet runs.
    func keepShowingPictures(of sheet: PawnSheet) async {
        guard let pictureRequests, let names = library?.pictureFiles(of: sheet), !names.isEmpty else { return }
        await pictureRequests.keepShowing(names)
    }

    /// Waits for the pictures a sheet lacks before it is exported or printed, for as long as they keep arriving.
    func waitForPictures(of sheet: PawnSheet) async {
        guard let pictureRequests, let names = library?.pictureFiles(of: sheet), !names.isEmpty else { return }
        isWaitingForPictures = !pictureRequests.missing(among: names).isEmpty
        await pictureRequests.show(names, givingUpAfter: Self.pictureStall)
        isWaitingForPictures = false
    }

    // MARK: Settings

    /// How many downloaded pictures this device keeps; nil while the library doesn't sync.
    func pictureKeeping() async -> PictureKeeping? {
        guard let policy = try? await sync?.picturePolicy() else { return nil }
        return PictureKeeping(policy)
    }

    func setPictureKeeping(_ keeping: PictureKeeping) async {
        do {
            try await sync?.setPicturePolicy(keeping.policy)
        } catch {
            errorMessage = "Changing how many pictures are kept failed: \(error)"
        }
    }

    /// The size of the pictures downloaded from iCloud, in bytes.
    func downloadedPictureBytes() async -> Int {
        (try? await sync?.fetchedPicturesByteCount()) ?? 0
    }

    /// Removes the downloaded pictures from this device; each comes back when its pawn is next shown.
    func removeDownloadedPictures() async {
        do {
            try await sync?.clearFetchedPictures()
        } catch {
            errorMessage = "Removing the downloaded pictures failed: \(error)"
        }
        picturesFetched += 1
    }

    /// Turns syncing back on after the user deleted the library's iCloud data (R10.7).
    func resumeSync() async {
        await sync?.resume()
    }

    // MARK: Helpers

    private func customPawnsMerged() {
        syncProblem = customPawnSync?.problem
        refresh()
    }
}
