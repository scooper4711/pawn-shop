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
        // Pawns added while a run is going are picked up by the next pass.
        var pending = library.pawnsNeedingTags(by: tagger.model)
        while !pending.isEmpty, problem == nil {
            await tag(pending, with: tagger)
            pending = library.pawnsNeedingTags(by: tagger.model)
        }
        progress = nil
    }

    private func tag(_ pawns: [Pawn], with tagger: OllamaTagger) async {
        defer { library.saveTags() }
        for (index, pawn) in pawns.enumerated() {
            progress = TaggingProgress(done: index, total: pawns.count)
            do {
                library.setTags(try await tags(of: pawn, with: tagger), by: tagger.model, of: pawn.id)
            } catch let error as PawnTaggingError where error.stopsTagging {
                problem = "\(error)"
                return
            } catch {
                // One pawn the model can't describe is left without tags rather than holding up the rest.
                library.setTags([], by: tagger.model, of: pawn.id)
            }
            if index % Self.saveInterval == Self.saveInterval - 1 { library.saveTags() }
        }
    }

    private func tags(of pawn: Pawn, with tagger: OllamaTagger) async throws -> [String] {
        guard let image = await library.backgroundRenderer?.artImage(of: pawn, height: Self.imageHeight)
        else { throw PawnTaggingError.unencodableImage }
        return try await tagger.tags(for: image, name: pawn.name)
    }
}
