import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import os
import SharedLibraries
import Testing
@testable import PawnShopCore

/// A stand-in for iCloud's pictures: it writes those it holds into the folder and records what it was asked.
final class FakePictureCloud: Sendable {
    private struct State {
        var held: Set<String> = []
        var asked: [[String]] = []
    }

    let folder: URL
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(folder: URL) {
        self.folder = folder
    }

    var asked: [[String]] { state.withLock { $0.asked } }

    func hold(_ names: [String]) { state.withLock { $0.held.formUnion(names) } }

    /// Downloads those of `names` it holds and the folder lacks, as `LibrarySync.fetchPictures(named:)` does.
    func fetch(_ names: [String]) -> Set<String> {
        let held = state.withLock { state in
            state.asked.append(names)
            return state.held
        }
        var fetched: Set<String> = []
        for name in names where held.contains(name) {
            let file = folder.appendingPathComponent(name)
            guard !FileManager.default.fileExists(atPath: file.path) else { continue }
            try? Data([1]).write(to: file)
            fetched.insert(name)
        }
        return fetched
    }
}

/// Asking iCloud for pictures a few at a time (R10.4).
@MainActor
@Suite struct PictureRequestsTests {
    let cloud: FakePictureCloud
    let requests: PictureRequests

    init() throws {
        let folder = temporaryFolder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let cloud = FakePictureCloud(folder: folder)
        self.cloud = cloud
        // Long enough for requests made together to meet in one round on a busy machine.
        requests = PictureRequests(pictures: folder, window: .milliseconds(150)) { cloud.fetch($0) }
    }

    @Test func asksOnceForWhatSeveralViewsWantAtTheSameMoment() async {
        cloud.hold(["a.heic", "b.heic"])
        var arrivals = 0
        requests.onArrival = { arrivals += 1 }
        async let first = requests.show(["a.heic"])
        async let second = requests.show(["b.heic", "c.heic", ""])
        async let third = requests.show(["c.heic"])
        let results = await [first, second, third]

        #expect(results == [true, true, false])
        #expect(cloud.asked == [["a.heic", "b.heic", "c.heic"]] && arrivals == 1)
        #expect(requests.missing(among: ["a.heic", "c.heic"]) == ["c.heic"])
    }

    @Test func doesNotAskAgainForAPictureItJustNoted() async {
        cloud.hold(["a.heic"])
        #expect(await requests.show(["a.heic"]))
        #expect(await !requests.show(["a.heic"]))
        #expect(await !requests.show([]))
        #expect(cloud.asked.count == 1)

        #expect(await !requests.show(["missing.heic"]))
        #expect(await !requests.show(["missing.heic"]))
        #expect(cloud.asked.count == 2, "a picture that didn't arrive isn't asked for again at once")
        await requests.show(["missing.heic", "a.heic"], givingUpAfter: .milliseconds(30))
        #expect(cloud.asked.last == ["missing.heic"], "but an export asks for it whenever it was last tried")
    }

    @Test func notesAPictureThatIsHereAsShown() async throws {
        try Data([1]).write(to: cloud.folder.appendingPathComponent("here.heic"))
        #expect(await !requests.show(["here.heic"]))
        #expect(cloud.asked == [["here.heic"]])
        #expect(await !requests.show(["here.heic"]))
        #expect(cloud.asked.count == 1)
    }

    @Test func asksForManyPicturesABatchAtATime() async {
        let names = (0..<60).map { String(format: "picture-%02d.heic", $0) }
        cloud.hold(names)
        var arrivals = 0
        requests.onArrival = { arrivals += 1 }
        #expect(await requests.show(names))
        #expect(cloud.asked.map(\.count) == [25, 25, 10] && arrivals == 3)
        #expect(requests.missing(among: names).isEmpty)
    }

    @Test func waitsForASheetsPicturesOnlyWhileTheyKeepComing() async throws {
        cloud.hold(["a.heic", "b.heic"])
        await requests.show(["a.heic", "b.heic"], givingUpAfter: .seconds(5))
        #expect(requests.missing(among: ["a.heic", "b.heic"]).isEmpty)
        await requests.show(["a.heic"], givingUpAfter: .seconds(5))
        #expect(cloud.asked.count == 1, "pictures that are here and noted aren't asked for")

        let slow = PictureRequests(pictures: cloud.folder, window: .milliseconds(5)) { _ in
            try? await Task.sleep(for: .seconds(3))
            return []
        }
        let start = ContinuousClock.now
        await slow.show(["never.heic"], givingUpAfter: .milliseconds(30))
        #expect(ContinuousClock.now - start < .seconds(2), "it gives up once nothing arrives")
    }

    @Test func listsThePicturesASheetIsDrawnFrom() throws {
        let folder = temporaryFolder()
        let sharedFolder = folder.appendingPathComponent("Shared")
        let drawn = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(variant: 0),
                              name: "GOBLIN WARRIOR")
        let pdf = try writePawnPDF([drawn], named: "Pathfinder Test Pawn Box.pdf", in: folder)
        try SharedLibrary(folder: sharedFolder, app: .turnkeeper).add(pdf, keeping: false)
        let library = try PawnLibrary(folder: folder.appendingPathComponent("Pawn Shop"),
                                      shared: try SharedLibrary(folder: sharedFolder, app: .pawnShop))
        let goblin = try #require(library.pawns.first)
        let hero = try library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: "Hero"))
        var sheet = PawnSheet()
        sheet.add(goblin.id, copies: 2)
        sheet.add(hero.id)
        sheet.add(UUID())
        sheet.add(.item("potion"))
        #expect(library.pictureFiles(of: sheet) == goblin.pictureFiles && goblin.pictureFiles.count == 1)
    }
}
