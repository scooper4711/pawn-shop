import Foundation

/// What Settings says under the tagging server's address.
public enum TaggingSettingsText {
    /// Where the pawns' pictures go for the address as typed, or that it isn't an address.
    public static func serverNote(for address: String) -> String {
        let typed = address.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return "The pictures go only to Ollama on this Mac." }
        guard let endpoint = OllamaTagger.endpoint(from: typed) else {
            let example = OllamaTagger.defaultEndpoint.absoluteString
            return "That isn't a server's address, such as \(example), so Ollama on this Mac is used."
        }
        return isThisMac(endpoint)
            ? "The pictures go only to Ollama on this Mac."
            : "The pictures go to \(endpoint.host ?? typed), and nowhere else."
    }

    private static func isThisMac(_ endpoint: URL) -> Bool {
        ["localhost", "127.0.0.1", "::1"].contains(endpoint.host?.lowercased() ?? "")
    }
}
