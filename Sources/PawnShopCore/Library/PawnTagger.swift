import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum PawnTaggingError: Error, Equatable, CustomStringConvertible {
    /// Ollama isn't running, or can't be reached.
    case unreachable(String)
    /// Ollama answered with an error, such as a model that isn't installed.
    case refused(String)
    /// The answer wasn't the list of tags asked for.
    case unreadableReply(String)
    case unencodableImage

    public var description: String {
        switch self {
        case .unreachable(let reason): "Tagging pawns failed: Ollama could not be reached (\(reason))"
        case .refused(let reason): "Tagging pawns failed: Ollama answered \"\(reason)\""
        case .unreadableReply(let reply): "Tagging pawns failed: the model's reply could not be read: \(reply)"
        case .unencodableImage: "Tagging pawns failed: the pawn's art could not be encoded"
        }
    }

    /// True when every pawn would fail the same way, so tagging should stop rather than go on.
    public var stopsTagging: Bool {
        switch self {
        case .unreachable, .refused: true
        case .unreadableReply, .unencodableImage: false
        }
    }
}

/// Describes a pawn's art in search keywords, asking a vision model that Ollama runs on this Mac.
public struct OllamaTagger: Sendable {
    public static let defaultModel = "gemma3:12b"
    public static let defaultEndpoint = URL(string: "http://localhost:11434")!

    static let prompt = """
        This is a pawn (a standee) for a tabletop role-playing game. List 3 to 10 lowercase search keywords for \
        what you can clearly see: who or what it is (woman, man, child, elf, dwarf, orc, goblin, dragon, skeleton, \
        robot, beast...; for a person, always say man or woman), their role if obvious (warrior, wizard, archer, \
        priest, rogue, knight...), and their weapons, armor, gear and animals (shield, scimitar, longsword, axe, \
        bow, spear, staff, gun, plate armor, cloak, wolf, horse...). Prefer specific weapon names, and list the \
        general kind as well: longsword and sword, scimitar and sword, longbow and bow, rifle and gun, plate armor \
        and armor. Do not use generic words such as fantasy, character, art or figure. Only list things you are \
        sure of.
        """

    public let model: String
    public let endpoint: URL
    let session: URLSession

    public init(model: String = defaultModel, endpoint: URL = defaultEndpoint, session: URLSession = .shared) {
        self.model = model
        self.endpoint = endpoint
        self.session = session
    }

    static let namePrompt = prompt + """
         Also suggest a name for the pawn of at most three words, like the names printed on pawns: the kind of \
        creature or person and their role, such as Goblin Archer, Elf Wizard, Fire Giant or Dwarf Priest.
        """

    /// What to ask the model for.
    enum Question {
        case tags
        case tagsAndName

        var prompt: String { self == .tags ? OllamaTagger.prompt : OllamaTagger.namePrompt }

        /// The JSON schema the answer must follow.
        var format: [String: Any] {
            let tags: [String: Any] = ["type": "array", "items": ["type": "string"]]
            return self == .tags
                ? ["type": "object", "required": ["tags"], "properties": ["tags": tags]]
                : ["type": "object", "required": ["tags", "name"],
                   "properties": ["tags": tags, "name": ["type": "string"]]]
        }
    }

    /// Keywords for what `image` shows, without `name` or words that describe every pawn.
    public func tags(for image: CGImage, name: String) async throws -> [String] {
        let reply = try await answer(.tags, about: image)
        return PawnTags.normalized(try Self.tags(fromReply: reply), name: name)
    }

    /// Keywords for what `image` shows and a name for it, for art printed without a name.
    public func tagsAndName(for image: CGImage) async throws -> PawnDescription {
        let reply = try await answer(.tagsAndName, about: image)
        let name = SuggestedName.normalized(try Self.name(fromReply: reply))
        guard !name.isEmpty else { throw PawnTaggingError.unreadableReply(String(decoding: reply, as: UTF8.self)) }
        return PawnDescription(tags: PawnTags.normalized(try Self.tags(fromReply: reply), name: name),
                               suggestedName: name)
    }

    private func answer(_ question: Question, about image: CGImage) async throws -> Data {
        let request = try request(for: Self.pngData(of: image), asking: question)
        do {
            return try await session.data(for: request).0
        } catch {
            throw PawnTaggingError.unreachable(error.localizedDescription)
        }
    }

    func request(for png: Data, asking question: Question) throws -> URLRequest {
        let body: [String: Any] = [
            "model": model, "prompt": question.prompt, "images": [png.base64EncodedString()], "stream": false,
            "format": question.format, "options": ["temperature": 0]
        ]
        var request = URLRequest(url: endpoint.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300
        return request
    }

    /// The tags in Ollama's reply: `{"response": "{\"tags\": [...]}"}`, or `{"error": "..."}`.
    static func tags(fromReply data: Data) throws -> [String] {
        guard let tags = try answer(fromReply: data)["tags"] as? [String] else {
            throw PawnTaggingError.unreadableReply(String(decoding: data, as: UTF8.self))
        }
        return tags
    }

    /// The name in Ollama's reply: `{"response": "{\"tags\": [...], \"name\": \"...\"}"}`.
    static func name(fromReply data: Data) throws -> String {
        guard let name = try answer(fromReply: data)["name"] as? String else {
            throw PawnTaggingError.unreadableReply(String(decoding: data, as: UTF8.self))
        }
        return name
    }

    /// The model's answer inside Ollama's reply, or the error Ollama answered with.
    private static func answer(fromReply data: Data) throws -> [String: Any] {
        let text = String(decoding: data, as: UTF8.self)
        guard let reply = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PawnTaggingError.unreadableReply(text)
        }
        if let error = reply["error"] as? String { throw PawnTaggingError.refused(error) }
        guard let response = (reply["response"] as? String)?.data(using: .utf8),
              let answer = try? JSONSerialization.jsonObject(with: response) as? [String: Any]
        else { throw PawnTaggingError.unreadableReply(text) }
        return answer
    }

    static func pngData(of image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw PawnTaggingError.unencodableImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PawnTaggingError.unencodableImage }
        return data as Data
    }
}

/// Search keywords describing what a pawn's art shows.
public enum PawnTags {
    /// Words that would describe every pawn, so they find nothing in particular.
    static let meaningless: Set<String> = ["fantasy", "character", "art", "artwork", "figure", "pawn", "standee",
                                           "illustration", "person"]

    /// Lowercased and trimmed, once each, without meaningless words or the pawn's own name.
    public static func normalized(_ tags: [String], name: String) -> [String] {
        cleaned(tags).filter { $0 != name.lowercased() && !meaningless.contains($0) }
    }

    /// Lowercased and trimmed, once each, without empty ones: the user's own tags are otherwise kept as typed.
    public static func cleaned(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        return tags.compactMap { tag in
            let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
            guard !clean.isEmpty, seen.insert(clean).inserted else { return nil }
            return clean
        }
    }

    /// The tags in a comma-separated list, as the user types them.
    public static func parsed(_ text: String) -> [String] {
        cleaned(text.split(separator: ",").map(String.init))
    }
}

/// What the model saw in art printed without a name.
public struct PawnDescription: Equatable, Sendable {
    public var tags: [String]
    public var suggestedName: String
}

/// A name the model suggests for a pawn printed without one.
public enum SuggestedName {
    static let maximumWords = 3
    /// Words left in lowercase inside a name, as in "Captain of Guards".
    static let minorWords: Set<String> = ["a", "an", "and", "of", "the", "in", "on", "with"]

    /// At most three words, trimmed of punctuation and capitalized like a printed name.
    public static func normalized(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }
            .prefix(maximumWords)
        return words.enumerated().map { index, word in
            index > 0 && minorWords.contains(word) ? word : word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }
}
