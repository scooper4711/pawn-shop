import CoreGraphics
import Foundation
import Testing
import ArtExtractionTestSupport
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

    override static func canInit(with _: URLRequest) -> Bool { true }
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

    override func stopLoading() {
        // Replies are delivered at once in startLoading, so there is nothing to stop.
    }
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
        let tags = PawnTags.normalized([" Cloak", "warrior.", "CLOAK", "", "fantasy", "Aldori Swordlord", "scimitar",
                                        "undead and dwarf", "Tabletop", "roleplaying game", "creature"],
                                       name: "Aldori Swordlord")
        #expect(tags == ["cloak", "warrior", "scimitar", "undead", "dwarf"])
    }

    @Test func leavesOutWhatSearchAlreadyFindsAndGenders() {
        let tags = PawnTags.normalized(["Skeleton", "guard", "undead", "Mindless", "woman", "male", "halberd",
                                        "skeleton guard", "night watch"],
                                       name: "Skeleton Guard, Night", traits: ["medium", "Undead", "mindless"])
        #expect(tags == ["halberd", "night watch"])
    }

    @Test func keepsAnUnnamedPawnsAncestryButNoGender() {
        #expect(PawnTags.described(["Elf", "woman", "wizard", "figure", "staff"]) == ["elf", "wizard", "staff"])
    }

    @Test func tellsTheModelTheNameAndTraitsAndAsksForNoGender() {
        let named = TaggingPrompt.named("Skeleton Guard", traits: ["medium", "undead"])
        #expect(named.contains("\"Skeleton Guard\"") && named.contains("Its game traits are: medium, undead."))
        #expect(named.contains("do not repeat them") && named.contains("Never give a gender"))
        #expect(!TaggingPrompt.named("Hero", traits: []).contains("game traits are"))
        #expect(TaggingPrompt.unnamed.contains("ancestry") && TaggingPrompt.unnamed.contains("Never give a gender"))
        for prompt in [named, TaggingPrompt.unnamed] {
            #expect(!prompt.contains("man or woman"))
        }
    }

    @Test func tagsAgainWhenTheModelOrThePromptsChange() {
        let signature = OllamaTagger(model: "gemma3:12b").signature
        #expect(signature == "gemma3:12b v\(TaggingPrompt.version)" && TaggingPrompt.version >= 2)
        var pawn = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png")))
        pawn.tagModel = "gemma3:12b"
        #expect(pawn.needsTagging(by: signature))
        pawn.tagModel = signature
        #expect(!pawn.needsTagging(by: signature) && pawn.needsTagging(by: OllamaTagger(model: "other").signature))
    }

    @Test func asksForTagsOfTheArt() throws {
        let tagger = OllamaTagger(model: "gemma3:4b", endpoint: URL(string: "http://ollama.test:1234")!)
        let question = OllamaTagger.Question.tags(name: "Goblin", traits: ["small"])
        let request = try tagger.request(for: Data("png".utf8), asking: question)
        #expect(request.url?.absoluteString == "http://ollama.test:1234/api/generate")
        #expect(request.httpMethod == "POST")
        let body = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(body["model"] as? String == "gemma3:4b")
        #expect(body["images"] as? [String] == [Data("png".utf8).base64EncodedString()])
        #expect(body["stream"] as? Bool == false)
        #expect((body["format"] as? [String: Any])?["required"] as? [String] == ["tags"])
        #expect(body["prompt"] as? String == TaggingPrompt.named("Goblin", traits: ["small"]))
    }

    @Test func asksForANameOnlyWhenAskedForTagsAndName() throws {
        let request = try OllamaTagger().request(for: Data("png".utf8), asking: .tagsAndName)
        let body = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        let format = try #require(body["format"] as? [String: Any])
        #expect(format["required"] as? [String] == ["tags", "name"])
        #expect((format["properties"] as? [String: Any])?["name"] != nil)
        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt == TaggingPrompt.unnamed && prompt.contains("at most three words"))
        #expect(!TaggingPrompt.named("Goblin", traits: []).contains("three words"))
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
        let reply = try ollamaReply(tags: ["Goblin", "fantasy", "small", "Dogslicer"])
        let session = StubOllama.session(host: "tagging.test", reply: reply)
        let tagger = OllamaTagger(endpoint: URL(string: "http://tagging.test")!, session: session)
        #expect(try await tagger.tags(for: artImage(), name: "Goblin Warrior", traits: ["small"]) == ["dogslicer"])
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
