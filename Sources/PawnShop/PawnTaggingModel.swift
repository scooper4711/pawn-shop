import CoreGraphics
import Foundation
import Observation
import PawnShopCore

/// Tags the library's pawns in the background with a vision model running in Ollama on this Mac.
@MainActor
@Observable
final class PawnTaggingModel {
    static let shared = PawnTaggingModel(library: .shared)
    /// Pixel height of the art shown to the model: enough to make out weapons, small enough to stay quick.
    static let imageHeight = 448
    /// Tags are saved after this many pawns, so quitting part way loses little.
    static let saveInterval = 10

    private(set) var isRunning = false
    /// Why the last run stopped early, until a run finishes.
    private(set) var problem: String?
    /// The Settings switch; turning it off stops tagging after the pawn in hand, and turning it on resumes.
    var isOn = OllamaTagger.isOn(in: .standard) {
        didSet {
            UserDefaults.standard.set(isOn, forKey: OllamaTagger.isOnKey)
            if isOn { tagNewPawns() }
        }
    }

    @ObservationIgnored private let library: LibraryModel
    /// Pawns this run has asked about, so one the model can't name isn't asked about again until the next run.
    @ObservationIgnored private var asked: Set<UUID> = []
    /// How many grids show each pawn; the pawns on screen are tagged next.
    @ObservationIgnored private var showing: [UUID: Int] = [:]

    init(library: LibraryModel) {
        self.library = library
    }

    /// The model, set with `defaults write <bundle id> TaggingModel <name>`; changing it tags every pawn again.
    var tagger: OllamaTagger { .configured(by: .standard) }

    /// How many of the library's pawns the current model has tagged; observed through the library's pawns.
    var progress: TaggingProgress { TaggingProgress(of: library.pawns, by: tagger.model) }

    /// Tags the pawns not yet tagged by the current model, quietly giving up when Ollama isn't there.
    func tagNewPawns() {
        start()
    }

    /// Notes a pawn appearing in a grid, so it is tagged ahead of the rest.
    func show(_ id: UUID) {
        showing[id, default: 0] += 1
    }

    func hide(_ id: UUID) {
        guard let count = showing[id] else { return }
        showing[id] = count > 1 ? count - 1 : nil
    }

    /// Like `tagNewPawns`, but reports a failure in an alert, for when the user asked for it.
    func tagNewPawnsReportingProblems() {
        start { [library] in library.errorMessage = $0 }
    }

    private func start(reportingProblem report: @escaping (String) -> Void = { _ in
        // Tagging in the background reports nothing: without Ollama, pawns simply stay untagged.
    }) {
        guard isOn, !isRunning else { return }
        isRunning = true
        Task {
            await run(tagger)
            isRunning = false
            if let problem { report(problem) }
        }
    }

    private func run(_ tagger: OllamaTagger) async {
        problem = nil
        asked = []
        defer { library.saveTags() }
        // The next pawn is chosen afresh each time, so pawns scrolled into view, or added, go ahead of the rest.
        var done = 0
        while isOn, problem == nil, let pawn = nextPawn(tagger) {
            await tag(pawn, with: tagger)
            done += 1
            if done.isMultiple(of: Self.saveInterval) { library.saveTags() }
        }
    }

    /// The pawn to tag next.
    private func nextPawn(_ tagger: OllamaTagger) -> Pawn? {
        library.pawnsNeedingTags(by: tagger.model, visible: Set(showing.keys)).first { !asked.contains($0.id) }
    }

    private func tag(_ pawn: Pawn, with tagger: OllamaTagger) async {
        asked.insert(pawn.id)
        do {
            try await describe(pawn, with: tagger)
        } catch let error as PawnTaggingError where error.stopsTagging {
            problem = "\(error)"
        } catch where pawn.tagModel != tagger.model {
            // One pawn the model can't describe is left without tags rather than holding up the rest.
            library.setTags([], by: tagger.model, of: pawn.id)
        } catch {
            // A pawn already tagged that the model couldn't name keeps its tags, and is asked again next run.
        }
    }

    /// Tags the pawn, and suggests a name for it too when it was printed without one.
    private func describe(_ pawn: Pawn, with tagger: OllamaTagger) async throws {
        let image = try await artImage(of: pawn)
        guard pawn.needsName else {
            library.setTags(try await tagger.tags(for: image, name: pawn.name), by: tagger.model, of: pawn.id)
            return
        }
        let description = try await tagger.tagsAndName(for: image)
        library.setTags(description.tags, by: tagger.model, of: pawn.id)
        library.setSuggestedName(description.suggestedName, of: pawn.id)
    }

    private func artImage(of pawn: Pawn) async throws -> CGImage {
        guard let image = await library.backgroundRenderer?.artImage(of: pawn, height: Self.imageHeight)
        else { throw PawnTaggingError.unencodableImage }
        return image
    }
}
