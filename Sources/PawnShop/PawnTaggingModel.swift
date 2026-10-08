import CoreGraphics
import Foundation
import Observation
import PawnShopCore

/// How far tagging has come.
struct TaggingProgress: Equatable {
    var done: Int
    var total: Int
}

/// Tags the library's pawns in the background with a vision model running in Ollama on this Mac.
@MainActor
@Observable
final class PawnTaggingModel {
    static let shared = PawnTaggingModel(library: .shared)
    /// Pixel height of the art shown to the model: enough to make out weapons, small enough to stay quick.
    static let imageHeight = 448
    /// Tags are saved after this many pawns, so quitting part way loses little.
    static let saveInterval = 10

    private(set) var progress: TaggingProgress?
    /// Why the last run stopped early, until a run finishes.
    private(set) var problem: String?

    @ObservationIgnored private let library: LibraryModel
    @ObservationIgnored private var isRunning = false
    /// Pawns this run has asked about, so one the model can't name isn't asked about again until the next run.
    @ObservationIgnored private var asked: Set<UUID> = []

    init(library: LibraryModel) {
        self.library = library
    }

    /// The model, set with `defaults write <bundle id> TaggingModel <name>`; changing it tags every pawn again.
    var tagger: OllamaTagger {
        let defaults = UserDefaults.standard
        let endpoint = defaults.string(forKey: "OllamaURL").flatMap(URL.init(string:))
            ?? OllamaTagger.defaultEndpoint
        return OllamaTagger(model: defaults.string(forKey: "TaggingModel") ?? OllamaTagger.defaultModel,
                            endpoint: endpoint)
    }

    /// Tags the pawns not yet tagged by the current model, quietly giving up when Ollama isn't there.
    func tagNewPawns() {
        start()
    }

    /// Like `tagNewPawns`, but reports a failure in an alert, for when the user asked for it.
    func tagNewPawnsReportingProblems() {
        start { [library] in library.errorMessage = $0 }
    }

    private func start(reportingProblem report: @escaping (String) -> Void = { _ in }) {
        guard !isRunning else { return }
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
        // Pawns added while a run is going are picked up by the next pass.
        var pending = pawnsToAsk(tagger)
        while !pending.isEmpty, problem == nil {
            await tag(pending, with: tagger)
            pending = pawnsToAsk(tagger)
        }
        progress = nil
    }

    private func pawnsToAsk(_ tagger: OllamaTagger) -> [Pawn] {
        library.pawnsNeedingTags(by: tagger.model).filter { !asked.contains($0.id) }
    }

    private func tag(_ pawns: [Pawn], with tagger: OllamaTagger) async {
        defer { library.saveTags() }
        for (index, pawn) in pawns.enumerated() {
            progress = TaggingProgress(done: index, total: pawns.count)
            asked.insert(pawn.id)
            do {
                try await describe(pawn, with: tagger)
            } catch let error as PawnTaggingError where error.stopsTagging {
                problem = "\(error)"
                return
            } catch where pawn.tagModel != tagger.model {
                // One pawn the model can't describe is left without tags rather than holding up the rest.
                library.setTags([], by: tagger.model, of: pawn.id)
            } catch {
                // A pawn already tagged that the model couldn't name keeps its tags, and is asked again next run.
            }
            if index % Self.saveInterval == Self.saveInterval - 1 { library.saveTags() }
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
