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
    let answer = String(bytes: try JSONSerialization.data(withJSONObject: ["tags": tags]), encoding: .utf8) ?? ""
    return try JSONSerialization.data(withJSONObject: ["model": "test", "response": answer, "done": true])
}

@Suite struct PawnTaggerTests {
    @Test func cleansUpTheModelsTags() {
        let tags = PawnTags.normalized([" Woman", "warrior.", "WOMAN", "", "fantasy", "Aldori Swordlord", "scimitar"],
                                       name: "Aldori Swordlord")
        #expect(tags == ["woman", "warrior", "scimitar"])
    }

    @Test func asksForTagsOfTheArt() throws {
        let tagger = OllamaTagger(model: "gemma3:4b", endpoint: URL(string: "http://ollama.test:1234")!)
        let request = try tagger.request(for: Data("png".utf8))
        #expect(request.url?.absoluteString == "http://ollama.test:1234/api/generate")
        #expect(request.httpMethod == "POST")
        let body = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(body["model"] as? String == "gemma3:4b")
        #expect(body["images"] as? [String] == [Data("png".utf8).base64EncodedString()])
        #expect(body["stream"] as? Bool == false)
        #expect((body["format"] as? [String: Any])?["required"] as? [String] == ["tags"])
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

    @Test func readsPawnsSavedBeforeTags() throws {
        var pawn = Pawn(name: "Old", size: .small, art: .custom(CustomArt(imageFile: "old.png")))
        pawn.tags = ["axe"]
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(pawn)) as? [String: Any])
        #expect(json["tags"] as? [String] == ["axe"])
        json["tags"] = nil
        json["tagModel"] = nil
        let old = try JSONDecoder().decode(Pawn.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.tags.isEmpty && old.tagModel.isEmpty)
    }
}

@Suite struct ArtImageTests {
    let library: PawnLibrary
    let renderer: PawnRenderer

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
        renderer = PawnRenderer(library: library)
    }

    /// How many pixels in rows `rows` (counted from the bottom) are near black.
    func darkPixels(in image: CGImage, rows: Range<Int>) -> Int {
        let canvas = Canvas(size: CGSize(width: image.width, height: image.height))
        canvas.context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = canvas.context.data!.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        var count = 0
        for row in rows {
            for column in 0..<image.width {
                let offset = ((image.height - 1 - row) * image.width + column) * 4
                if pixels[offset] < 90 && pixels[offset + 1] < 90 && pixels[offset + 2] < 90 { count += 1 }
            }
        }
        return count
    }

    @Test func paintsOutThePrintedNameButKeepsTheArt() throws {
        let folder = temporaryFolder()
        let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(), name: "GOBLIN")
        try library.importPDF(at: writePawnPDF([goblin], named: "Goblins.pdf", in: folder))
        let pawn = try #require(library.pawns.first)
        let printed = try #require(renderer.thumbnail(of: pawn, height: 138))
        let art = try #require(renderer.artImage(of: pawn, height: 138))
        // The name is printed 4 to 18 points above the foot; the art starts at 20.
        #expect(darkPixels(in: printed, rows: 4..<18) > 0)
        #expect(darkPixels(in: art, rows: 0..<19) == 0)
        #expect(darkPixels(in: art, rows: 20..<118) == darkPixels(in: printed, rows: 20..<118))
    }

    @Test func leavesTheNameOffCustomPawns() throws {
        writePNG(headRedImage(), to: library.customFolder.appendingPathComponent("hero.png"))
        let hero = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png", showsName: true)))
        let printed = try #require(renderer.thumbnail(of: hero, height: 138))
        let art = try #require(renderer.artImage(of: hero, height: 138))
        #expect(darkPixels(in: printed, rows: 0..<18) > 0)
        #expect(darkPixels(in: art, rows: 0..<18) == 0)
    }
}
