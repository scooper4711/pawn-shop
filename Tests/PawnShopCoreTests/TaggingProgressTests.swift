import Foundation
import Testing
@testable import PawnShopCore

@Suite struct TaggingProgressTests {
    let model = "gemma3:12b"

    func pawn(_ name: String, taggedBy tagModel: String = "", needsName: Bool = false) -> Pawn {
        var pawn = Pawn(name: name, size: .medium, art: .custom(CustomArt(imageFile: "\(name).png")),
                        needsName: needsName)
        pawn.tagModel = tagModel
        return pawn
    }

    @Test func countsThePawnsTheModelHasTaggedAndThoseLeft() {
        var corrected = pawn("Hero", taggedBy: "another-model")
        corrected.tagsCorrected = true
        let pawns = [pawn("Ogre", taggedBy: model), corrected, pawn("Goblin"), pawn("Orc", taggedBy: "another-model")]
        let progress = TaggingProgress(of: pawns, by: model)
        #expect(progress == TaggingProgress(done: 2, total: 4))
        #expect(progress.remaining == 2 && !progress.isComplete && progress.fraction == 0.5)
        #expect(progress.summary == "2 of 4 pawns tagged, 2 left")
    }

    @Test func countsAPawnNeedingANameUntilTheModelSuggestsOne() {
        var unnamed = pawn("Pawn 1", taggedBy: model, needsName: true)
        #expect(TaggingProgress(of: [unnamed], by: model).remaining == 1)
        unnamed.suggestedName = "Elf Wizard"
        let progress = TaggingProgress(of: [unnamed], by: model)
        #expect(progress.isComplete && progress.fraction == 1)
        #expect(progress.summary == "1 of 1 pawn tagged")
    }

    @Test func treatsAnEmptyLibraryAsFinished() {
        let progress = TaggingProgress(of: [], by: model)
        #expect(progress.isComplete && progress.fraction == 1 && progress.summary == "No pawns to tag")
    }

    @Test func tagsUnlessTurnedOff() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        #expect(OllamaTagger.isOn(in: defaults))
        defaults.set(false, forKey: OllamaTagger.isOnKey)
        #expect(!OllamaTagger.isOn(in: defaults))
        defaults.set(true, forKey: OllamaTagger.isOnKey)
        #expect(OllamaTagger.isOn(in: defaults))
    }

    @Test func usesTheModelAndEndpointTheUserChose() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let standard = OllamaTagger.configured(by: defaults)
        #expect(standard.model == OllamaTagger.defaultModel && standard.endpoint == OllamaTagger.defaultEndpoint)
        defaults.set("llava:7b", forKey: "TaggingModel")
        defaults.set("http://studio.local:11434", forKey: "OllamaURL")
        let chosen = OllamaTagger.configured(by: defaults)
        #expect(chosen.model == "llava:7b" && chosen.endpoint.host == "studio.local")
    }
}
