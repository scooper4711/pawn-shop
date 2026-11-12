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

    @Test func tagsOnlyOnceTurnedOn() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        #expect(!OllamaTagger.isOn(in: defaults))
        defaults.set(true, forKey: OllamaTagger.isOnKey)
        #expect(OllamaTagger.isOn(in: defaults))
        defaults.set(false, forKey: OllamaTagger.isOnKey)
        #expect(!OllamaTagger.isOn(in: defaults))
    }

    @Test func usesTheModelAndEndpointTheUserChose() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let standard = OllamaTagger.configured(by: defaults)
        #expect(standard.model == OllamaTagger.defaultModel && standard.endpoint == OllamaTagger.defaultEndpoint)
        defaults.set("llava:7b", forKey: OllamaTagger.modelKey)
        defaults.set("http://studio.local:11434", forKey: OllamaTagger.endpointKey)
        let chosen = OllamaTagger.configured(by: defaults)
        #expect(chosen.model == "llava:7b" && chosen.endpoint.host == "studio.local")
        #expect(!chosen.matches(standard) && chosen.matches(.configured(by: defaults)))
    }

    @Test(arguments: ["", "  ", "studio", "ftp://studio.local", "http://"])
    func usesTheDefaultsForWhatIsNotAModelOrAnAddress(typed: String) {
        let tagger = OllamaTagger.configured(model: "  ", address: typed)
        #expect(tagger.model == OllamaTagger.defaultModel && tagger.endpoint == OllamaTagger.defaultEndpoint)
        #expect(OllamaTagger.endpoint(from: typed) == nil)
    }

    @Test func trimsWhatWasTyped() {
        let tagger = OllamaTagger.configured(model: " gemma3:4b ", address: " https://tags.example.com:8443 ")
        #expect(tagger.model == "gemma3:4b" && tagger.endpoint.absoluteString == "https://tags.example.com:8443")
    }

    @Test func explainsWhatToDoWhenTaggingStops() {
        let tagger = OllamaTagger.configured(model: "gemma3:4b", address: "http://studio.local:11434")
        let unreachable = tagger.explanation(of: .unreachable("Could not connect to the server."))
        #expect(unreachable.contains("http://studio.local:11434") && unreachable.contains("Start Ollama"))
        let refused = tagger.explanation(of: .refused("model 'gemma3:4b' not found"))
        #expect(refused.contains("not found") && refused.contains("ollama pull gemma3:4b"))
        #expect(tagger.explanation(of: .unencodableImage) == PawnTaggingError.unencodableImage.description)
    }

    @Test func saysWhereThePicturesGo() {
        let onThisMac = "The pictures go only to Ollama on this Mac."
        #expect(TaggingSettingsText.serverNote(for: "") == onThisMac)
        #expect(TaggingSettingsText.serverNote(for: "http://LOCALHOST:11434") == onThisMac)
        #expect(TaggingSettingsText.serverNote(for: "http://127.0.0.1:11434") == onThisMac)
        #expect(TaggingSettingsText.serverNote(for: "http://studio.local:11434")
            == "The pictures go to studio.local, and nowhere else.")
        #expect(TaggingSettingsText.serverNote(for: "studio").contains("isn't a server's address"))
    }
}
