import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// Answers requests to a test's own host with a canned reply, or fails them, without touching the network.
final class StubOllama: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [String: Data] = [:]

    /// A session whose requests to `host` get `reply`; with no reply they fail as if nothing were listening.
    static func session(host: String, reply: Data?) -> URLSession {
        lock.withLock { replies[host] = reply }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubOllama.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let reply = Self.lock.withLock({ Self.replies[request.url?.host ?? ""] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Ollama's reply carrying `tags` as the model's answer.
func ollamaReply(tags: [String]) throws -> Data {
    try ollamaReply(answer: ["tags": tags])
}

/// Ollama's reply carrying `answer` as the model's JSON answer.
func ollamaReply(answer: [String: Any]) throws -> Data {
    let text = String(bytes: try JSONSerialization.data(withJSONObject: answer), encoding: .utf8) ?? ""
    return try JSONSerialization.data(withJSONObject: ["model": "test", "response": text, "done": true])
}

@Suite struct PawnTaggerTests {
    @Test func cleansUpTheModelsTags() {
        let tags = PawnTags.normalized([" Woman", "warrior.", "WOMAN", "", "fantasy", "Aldori Swordlord", "scimitar",
                                        "undead and dwarf", "Tabletop", "roleplaying game", "creature"],
                                       name: "Aldori Swordlord")
        #expect(tags == ["woman", "warrior", "scimitar", "undead", "dwarf"])
    }

    @Test func asksForTagsOfTheArt() throws {
        let tagger = OllamaTagger(model: "gemma3:4b", endpoint: URL(string: "http://ollama.test:1234")!)
        let request = try tagger.request(for: Data("png".utf8), asking: .tags)
        #expect(request.url?.absoluteString == "http://ollama.test:1234/api/generate")
        #expect(request.httpMethod == "POST")
        let body = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(body["model"] as? String == "gemma3:4b")
        #expect(body["images"] as? [String] == [Data("png".utf8).base64EncodedString()])
        #expect(body["stream"] as? Bool == false)
        #expect((body["format"] as? [String: Any])?["required"] as? [String] == ["tags"])
        #expect(body["prompt"] as? String == OllamaTagger.prompt)
        #expect(OllamaTagger.prompt.contains("vehicle") && OllamaTagger.prompt.contains("undead"))
    }

    @Test func asksForANameOnlyWhenAskedForTagsAndName() throws {
        let request = try OllamaTagger().request(for: Data("png".utf8), asking: .tagsAndName)
        let body = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        let format = try #require(body["format"] as? [String: Any])
        #expect(format["required"] as? [String] == ["tags", "name"])
        #expect((format["properties"] as? [String: Any])?["name"] != nil)
        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.hasPrefix(OllamaTagger.prompt) && prompt.contains("at most three words"))
        #expect(!OllamaTagger.prompt.contains("three words"))
    }

    @Test func readsTheUsersKeywords() {
        #expect(PawnTags.parsed(" Dwarf, undead,, UNDEAD , war hammer.") == ["dwarf", "undead", "war hammer"])
        #expect(PawnTags.parsed("  ").isEmpty)
    }

    @Test func tidiesTheSuggestedName() {
        #expect(SuggestedName.normalized("  goblin ARCHER. ") == "Goblin Archer")
        #expect(SuggestedName.normalized("captain of the guard") == "Captain of the")
        #expect(SuggestedName.normalized("the frost giant jarl") == "The Frost Giant")
        #expect(SuggestedName.normalized("half-orc") == "Half-orc")
        #expect(SuggestedName.normalized(" ... ").isEmpty)
    }

    @Test func tagsAndNamesAnImageThroughOllama() async throws {
        let reply = try ollamaReply(answer: ["tags": ["Goblin", "bow", "fantasy"], "name": "goblin archer"])
        let tagger = OllamaTagger(endpoint: URL(string: "http://naming.test")!,
                                  session: StubOllama.session(host: "naming.test", reply: reply))
        let description = try await tagger.tagsAndName(for: artImage())
        #expect(description == PawnDescription(tags: ["goblin", "bow"], suggestedName: "Goblin Archer"))
    }

    @Test(arguments: zip([1, 2, 3],
                         [#"{"tags": ["bow"]}"#, #"{"tags": ["bow"], "name": " . "}"#, #"{"name": "Goblin"}"#]))
    func reportsRepliesWithoutAName(index: Int, answer: String) async throws {
        let host = "unnamed\(index).test"
        let reply = try JSONSerialization.data(withJSONObject: ["response": answer])
        let tagger = OllamaTagger(endpoint: URL(string: "http://\(host)")!,
                                  session: StubOllama.session(host: host, reply: reply))
        await #expect {
            try await tagger.tagsAndName(for: artImage())
        } throws: { error in
            (error as? PawnTaggingError).map { if case .unreadableReply = $0 { true } else { false } } ?? false
        }
    }

    @Test func readsTheTagsFromTheReply() throws {
        #expect(try OllamaTagger.tags(fromReply: ollamaReply(tags: ["shield", "axe"])) == ["shield", "axe"])
    }

    @Test(arguments: [(#"{"error": "model 'x' not found"}"#, PawnTaggingError.refused("model 'x' not found")),
                      ("not json", .unreadableReply("not json")),
                      (#"{"response": "{\"words\": []}"}"#, .unreadableReply(#"{"response": "{\"words\": []}"}"#))])
    func reportsRepliesWithoutTags(reply: String, error: PawnTaggingError) {
        #expect(throws: error) { try OllamaTagger.tags(fromReply: Data(reply.utf8)) }
    }

    @Test func tagsAnImageThroughOllama() async throws {
        let session = StubOllama.session(host: "tagging.test", reply: try ollamaReply(tags: ["Goblin", "fantasy"]))
        let tagger = OllamaTagger(endpoint: URL(string: "http://tagging.test")!, session: session)
        #expect(try await tagger.tags(for: artImage(), name: "Goblin Warrior") == ["goblin"])
    }

    @Test func reportsOllamaNotRunning() async {
        let session = StubOllama.session(host: "nothing.test", reply: nil)
        let tagger = OllamaTagger(endpoint: URL(string: "http://nothing.test")!, session: session)
        await #expect {
            try await tagger.tags(for: artImage(), name: "Goblin")
        } throws: { error in
            (error as? PawnTaggingError).map { if case .unreachable = $0 { true } else { false } } ?? false
        }
    }

    @Test func stopsOnlyWhenEveryPawnWouldFail() {
        #expect(PawnTaggingError.unreachable("x").stopsTagging && PawnTaggingError.refused("x").stopsTagging)
        #expect(!PawnTaggingError.unreadableReply("x").stopsTagging && !PawnTaggingError.unencodableImage.stopsTagging)
        for error in [PawnTaggingError.unreachable("down"), .refused("down"), .unreadableReply("down")] {
            #expect(error.description.hasPrefix("Tagging pawns failed") && error.description.contains("down"))
        }
        #expect(PawnTaggingError.unencodableImage.description.contains("encoded"))
    }
}

@Suite struct PawnTagStorageTests {
    let folder = temporaryFolder()

    func library() throws -> PawnLibrary { try PawnLibrary(folder: folder.appendingPathComponent("Library")) }

    @Test func keepsTagsBetweenLaunchesAndFindsPawnsByThem() throws {
        let library = try library()
        let hero = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png")))
        let ogre = Pawn(name: "Ogre", size: .large, art: .custom(CustomArt(imageFile: "ogre.png")))
        try library.add(hero)
        try library.add(ogre)
        #expect(library.pawnsNeedingTags(by: "gemma3:4b").count == 2)
        library.setTags(["woman", "scimitar"], by: "gemma3:4b", of: hero.id)
        library.setTags(["club"], by: "gemma3:4b", of: UUID())
        try library.save()
        let reopened = try self.library()
        #expect(reopened.pawn(id: hero.id)?.tags == ["woman", "scimitar"])
        #expect(reopened.pawnsNeedingTags(by: "gemma3:4b").map(\.name) == ["Ogre"])
        #expect(reopened.pawnsNeedingTags(by: "another-model").count == 2)
        #expect(reopened.search(PawnQuery(text: "Scimitar woman")).map(\.name) == ["Hero"])
    }

    @Test func matchesTagsFromTheStartOfTheirWords() throws {
        let library = try library()
        let names = ["Hero", "Heroine", "Ogre"]
        let tags = [["man", "longsword"], ["woman", "plate armor"], ["club"]]
        for (name, tags) in zip(names, tags) {
            try library.add(Pawn(name: name, size: .medium, art: .custom(CustomArt(imageFile: "x.png"))))
            library.setTags(tags, by: "model", of: library.pawns.last!.id)
        }
        #expect(library.search(PawnQuery(text: "man")).map(\.name) == ["Hero"])
        #expect(library.search(PawnQuery(text: "wom")).map(\.name) == ["Heroine"])
        #expect(library.search(PawnQuery(text: "armor")).map(\.name) == ["Heroine"])
        #expect(library.search(PawnQuery(text: "long")).map(\.name) == ["Hero"])
        #expect(library.search(PawnQuery(text: "sword")).isEmpty)
        #expect(library.search(PawnQuery(text: "ogr")).map(\.name) == ["Ogre"])
    }

    @Test func asksAboutPawnsNeedingANameFirstUntilOneIsSuggested() throws {
        let library = try library()
        let named = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png")))
        let nameless = Pawn(name: "Unknown Heroes", size: .medium, art: .custom(CustomArt(imageFile: "x.png")),
                            needsName: true)
        try library.add(named)
        try library.add(nameless)
        #expect(library.pawnsNeedingTags(by: "model").map(\.id) == [nameless.id, named.id])
        library.setTags(["bow"], by: "model", of: named.id)
        library.setTags(["bow"], by: "model", of: nameless.id)
        #expect(library.pawnsNeedingTags(by: "model").map(\.id) == [nameless.id])
        library.setSuggestedName("Elf Archer", of: nameless.id)
        library.setSuggestedName("Ignored", of: UUID())
        try library.save()
        let reopened = try self.library()
        #expect(reopened.pawn(id: nameless.id)?.suggestedName == "Elf Archer")
        #expect(reopened.pawnsNeedingTags(by: "model").isEmpty)
        try reopened.rename(nameless.id, to: "Elf Archer")
        #expect(reopened.pawn(id: nameless.id)?.suggestedName == "")
        #expect(reopened.pawn(id: nameless.id)?.needsName == false)
    }

    @Test func asksAboutPawnsOnScreenFirst() throws {
        let library = try library()
        let names = ["First", "Second", "Third", "Fourth"]
        for name in names {
            try library.add(Pawn(name: name, size: .medium, art: .custom(CustomArt(imageFile: "x.png")),
                                 needsName: name == "Fourth"))
        }
        let ids = Dictionary(uniqueKeysWithValues: library.pawns.map { ($0.name, $0.id) })
        let order = { (visible: Set<String>) in
            library.pawnsNeedingTags(by: "model", visible: Set(visible.compactMap { ids[$0] })).map(\.name)
        }
        #expect(order([]) == ["Fourth", "First", "Second", "Third"])
        #expect(order(["Third", "Second"]) == ["Second", "Third", "Fourth", "First"])
        library.setTags(["axe"], by: "model", of: ids["Second"]!)
        #expect(order(["Third", "Second"]) == ["Third", "Fourth", "First"])
    }

    @Test func keepsTagsTheUserCorrected() throws {
        let library = try library()
        let forgeSpurned = Pawn(name: "Accursed Forge-Spurned", size: .medium,
                                art: .custom(CustomArt(imageFile: "x.png")))
        let nameless = Pawn(name: "Unknown Heroes", size: .medium, art: .custom(CustomArt(imageFile: "y.png")),
                            needsName: true)
        try library.add(forgeSpurned)
        try library.add(nameless)
        library.setTags(["orc"], by: "model", of: forgeSpurned.id)
        try library.correctTags(["Undead", "dwarf", "undead"], of: forgeSpurned.id)
        try library.correctTags(["elf"], of: nameless.id)
        try library.correctTags(["x"], of: UUID())
        library.setTags(["orc"], by: "model", of: forgeSpurned.id)
        let reopened = try self.library()
        #expect(reopened.pawn(id: forgeSpurned.id)?.tags == ["undead", "dwarf"])
        #expect(reopened.pawn(id: forgeSpurned.id)?.tagsCorrected == true)
        // A new model leaves corrected tags alone, but a pawn needing a name is still asked for one.
        #expect(reopened.pawnsNeedingTags(by: "another-model").map(\.id) == [nameless.id])
        reopened.setTags(["goblin"], by: "another-model", of: nameless.id)
        #expect(reopened.pawn(id: nameless.id)?.tags == ["elf"])
        #expect(reopened.search(PawnQuery(text: "dwarf")).map(\.id) == [forgeSpurned.id])
    }

    @Test func readsPawnsSavedBeforeTags() throws {
        var pawn = Pawn(name: "Old", size: .small, art: .custom(CustomArt(imageFile: "old.png")))
        pawn.tags = ["axe"]
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(pawn)) as? [String: Any])
        #expect(json["tags"] as? [String] == ["axe"])
        json["tags"] = nil
        json["tagModel"] = nil
        json["suggestedName"] = nil
        json["tagsCorrected"] = nil
        let old = try JSONDecoder().decode(Pawn.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.tags.isEmpty && old.tagModel.isEmpty && old.suggestedName.isEmpty && !old.tagsCorrected)
    }
}
