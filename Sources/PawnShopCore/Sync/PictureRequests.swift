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
    /// How long a picture that didn't arrive isn't asked for again: no device may have uploaded it yet, and a
    /// library's worth of those would otherwise be asked for at every scroll.
    public static let retryInterval: TimeInterval = 60

    private let folder: URL
    private let window: Duration
    private let retryAfter: TimeInterval
    private let fetch: Fetch
    private var waiting: Set<String> = []
    private var round: Task<Set<String>, Never>?
    private var noted: [String: Date] = [:]
    /// When each picture that didn't arrive was last asked for.
    private var tried: [String: Date] = [:]
    /// Called each time a request brought pictures, so what shows them is drawn again.
    public var onArrival: (@MainActor () -> Void)?

    /// Requests for the pictures in `folder`, the library's pictures folder, gathered for `window` before they are
    /// sent. A picture that didn't arrive is asked for again `retryAfter` seconds later at the earliest.
    public init(pictures folder: URL, window: Duration = .milliseconds(50),
                retryAfter: TimeInterval = PictureRequests.retryInterval, fetch: @escaping Fetch) {
        self.folder = folder
        self.window = window
        self.retryAfter = retryAfter
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
        await ask(for: names.filter { needsAsking($0) || isDue($0) })
    }

    /// Shows pictures for as long as something shows them, such as a tile on screen or an open sheet: those that
    /// didn't arrive are asked for again, `retryAfter` apart, until all are here or the task is cancelled. A picture
    /// no device had uploaded yet then turns up once one has, without the pawn having to leave the screen and come
    /// back. `draw` is called each time some arrive.
    public func keepShowing(_ names: [String], whenSomeArrive draw: @MainActor () async -> Void = {}) async {
        while !Task.isCancelled {
            if await show(names) { await draw() }
            guard !missing(among: names).isEmpty else { return }
            try? await Task.sleep(for: .seconds(retryAfter) + .milliseconds(50))
        }
    }

    /// Shows pictures and waits for those the device lacks, as an export or a print does, but only for as long as
    /// they keep arriving: once `stall` passes with none, as without a connection, it returns and leaves the
    /// rest to arrive later.
    public func show(_ names: [String], givingUpAfter stall: Duration) async {
        let lacking = missing(among: names)
        guard !lacking.isEmpty else {
            await show(names)
            return
        }
        // Asked for whenever they were last tried: an export is worth a request.
        let asked = names.filter(needsAsking) + lacking
        let (finished, continuation) = AsyncStream.makeStream(of: Void.self)
        Task {
            _ = await ask(for: asked)
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

    /// Sends `names` with the round that is gathering, or a new one. True when any of them arrived.
    private func ask(for names: [String]) async -> Bool {
        guard !names.isEmpty else { return false }
        waiting.formUnion(names)
        let fetched = await (round ?? startRound()).value
        return !fetched.isDisjoint(with: names)
    }

    /// True for a picture that is here and hasn't been noted as shown for a while.
    private func needsAsking(_ name: String) -> Bool {
        guard !name.isEmpty, isHere(name) else { return false }
        return Date().timeIntervalSince(noted[name] ?? .distantPast) > Self.notedFor
    }

    /// True for a picture that isn't here and wasn't asked for in the last `retryAfter` seconds.
    private func isDue(_ name: String) -> Bool {
        guard !name.isEmpty, !isHere(name) else { return false }
        return Date().timeIntervalSince(tried[name] ?? .distantPast) > retryAfter
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
            for name in batch {
                if isHere(name) {
                    noted[name] = now
                } else {
                    tried[name] = now
                }
            }
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
