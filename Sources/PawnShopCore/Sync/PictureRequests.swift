import Foundation

/// Asks iCloud for the pictures pawns are drawn from on a device without their PDFs (R10.4). The names asked for
/// within a moment go up together, a batch at a time, so a grid of tiles or a sheet costs a few requests and not
/// one per pawn. Asking also notes pictures as shown, which keeps a device with a size limit from removing those
/// in use; a picture that is here and was noted in the last half hour isn't asked about again.
@MainActor
public final class PictureRequests {
    /// Downloads those of the names the device lacks, notes all of them as shown, and returns those downloaded
    /// (`LibrarySync.fetchPictures(named:)`).
    public typealias Fetch = @Sendable ([String]) async -> Set<String>

    /// How many pictures go in one request, as the toolkit's own transfers do.
    public static let batchSize = 25
    /// How long a picture counts as noted (half the toolkit's hour of grace).
    static let notedFor: TimeInterval = 1_800

    private let folder: URL
    private let window: Duration
    private let fetch: Fetch
    private var waiting: Set<String> = []
    private var round: Task<Set<String>, Never>?
    private var noted: [String: Date] = [:]
    /// Called each time a request brought pictures, so what shows them is drawn again.
    public var onArrival: (@MainActor () -> Void)?

    /// Requests for the pictures in `folder`, the library's pictures folder, gathered for `window` before they are
    /// sent.
    public init(pictures folder: URL, window: Duration = .milliseconds(50), fetch: @escaping Fetch) {
        self.folder = folder
        self.window = window
        self.fetch = fetch
    }

    /// Those of `names` whose files aren't on the device.
    public func missing(among names: [String]) -> [String] {
        names.filter { !isHere($0) }
    }

    /// Shows pictures: downloads those the device lacks and notes the others as shown. True when any of `names`
    /// arrived, and what shows it should be drawn again.
    @discardableResult
    public func show(_ names: [String]) async -> Bool {
        let asked = names.filter(needsAsking)
        guard !asked.isEmpty else { return false }
        waiting.formUnion(asked)
        let fetched = await (round ?? startRound()).value
        return !fetched.isDisjoint(with: asked)
    }

    /// Shows pictures and waits for those the device lacks, as an export or a print does, but only for as long as
    /// they keep arriving: once `stall` passes with none, as without a connection, it returns and leaves the
    /// rest to arrive later.
    public func show(_ names: [String], givingUpAfter stall: Duration) async {
        guard !missing(among: names).isEmpty else {
            await show(names)
            return
        }
        let (finished, continuation) = AsyncStream.makeStream(of: Void.self)
        Task {
            await show(names)
            continuation.yield()
        }
        Task {
            var left = missing(among: names).count
            while left > 0 {
                try? await Task.sleep(for: stall)
                let now = missing(among: names).count
                if now >= left { break }
                left = now
            }
            continuation.yield()
        }
        for await _ in finished { break }
    }

    // MARK: Helpers

    /// True for a picture that isn't here, or that hasn't been noted as shown for a while.
    private func needsAsking(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        guard isHere(name), let last = noted[name] else { return true }
        return Date().timeIntervalSince(last) > Self.notedFor
    }

    private func isHere(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    private func startRound() -> Task<Set<String>, Never> {
        let task = Task {
            try? await Task.sleep(for: window)
            return await sendWaiting()
        }
        round = task
        return task
    }

    /// Sends what is waiting, a batch at a time; names asked for meanwhile wait for the next round.
    private func sendWaiting() async -> Set<String> {
        let names = waiting.sorted()
        waiting = []
        round = nil
        var fetched: Set<String> = []
        for start in stride(from: 0, to: names.count, by: Self.batchSize) {
            let batch = Array(names[start..<min(start + Self.batchSize, names.count)])
            let arrived = await fetch(batch)
            let now = Date()
            for name in batch where isHere(name) { noted[name] = now }
            fetched.formUnion(arrived)
            if !arrived.isEmpty { onArrival?() }
        }
        return fetched
    }
}

extension PawnLibrary {
    /// The picture files the sheet's pawns are drawn from, each once (`Pawn.pictureFiles`).
    public func pictureFiles(of sheet: PawnSheet) -> [String] {
        var seen: Set<String> = []
        return sheet.entries.compactMap(\.pawnID).compactMap(pawn(id:)).flatMap(\.pictureFiles)
            .filter { seen.insert($0).inserted }
    }
}
