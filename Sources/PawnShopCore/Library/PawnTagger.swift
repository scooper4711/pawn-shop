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

    /// Keywords for what `image` shows, without `name` or words that describe every pawn.
    public func tags(for image: CGImage, name: String) async throws -> [String] {
        let request = try request(for: Self.pngData(of: image))
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw PawnTaggingError.unreachable(error.localizedDescription)
        }
        return PawnTags.normalized(try Self.tags(fromReply: data), name: name)
    }

    func request(for png: Data) throws -> URLRequest {
        let body: [String: Any] = [
            "model": model, "prompt": Self.prompt, "images": [png.base64EncodedString()], "stream": false,
            "format": ["type": "object", "required": ["tags"],
                       "properties": ["tags": ["type": "array", "items": ["type": "string"]]]],
            "options": ["temperature": 0]
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
        let text = String(bytes: data, encoding: .utf8) ?? "\(data.count) bytes"
        guard let reply = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PawnTaggingError.unreadableReply(text)
        }
        if let error = reply["error"] as? String { throw PawnTaggingError.refused(error) }
        guard let response = (reply["response"] as? String)?.data(using: .utf8),
              let answer = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
              let tags = answer["tags"] as? [String]
        else { throw PawnTaggingError.unreadableReply(text) }
        return tags
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
        var seen: Set<String> = [name.lowercased()]
        return tags.compactMap { tag in
            let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
            guard !clean.isEmpty, !meaningless.contains(clean), seen.insert(clean).inserted else { return nil }
            return clean
        }
    }
}
