import CreatureImport
import Foundation

/// The names the pf2e system shows for traits, usages and weapon groups: each slug's localization key, from the
/// maps in `src/scripts/config`, looked up in the language files.
public struct ConfigLabels: Sendable {
    private let localizer: Localizer
    private let traitKeys: [String: String]
    private let usageKeys: [String: String]

    public init(localizer: Localizer, traitKeys: [String: String] = [:], usageKeys: [String: String] = [:]) {
        self.localizer = localizer
        self.traitKeys = traitKeys
        self.usageKeys = usageKeys
    }

    /// Reads the maps in the repository's `traits.ts` and `usage.ts`.
    public init(repository: URL, localizer: Localizer) {
        let config = repository.appendingPathComponent("src/scripts/config")
        self.init(localizer: localizer,
                  traitKeys: Self.keys(in: config.appendingPathComponent("traits.ts")),
                  usageKeys: Self.keys(in: config.appendingPathComponent("usage.ts")))
    }

    /// "Versatile P" for `versatile-p`.
    public func trait(_ slug: String) -> String {
        label(traitKeys[slug] ?? "PF2E.Trait" + Self.pascalCase(slug), slug: slug)
    }

    /// "held in 1 hand" for `held-in-one-hand`, in lowercase as the books print it.
    public func usage(_ slug: String) -> String {
        guard let key = usageKeys[slug], let text = localizer.text(for: key) else {
            return slug.replacingOccurrences(of: "-", with: " ")
        }
        return text.lowercased()
    }

    /// A document's traits as the books print them: the rarity first when it isn't common, then the traits.
    public func traits(_ traits: JSONValue) -> [String] {
        let rarity = traits["rarity"].string
        let rarityLabel = rarity.isEmpty || rarity == "common" ? [] : [Self.titleCase(rarity)]
        return rarityLabel + traits["value"].strings.map(trait)
    }

    /// "Sword" for `sword`.
    public func weaponGroup(_ slug: String) -> String {
        label("PF2E.WeaponGroup" + Self.pascalCase(slug), slug: slug)
    }

    private func label(_ key: String, slug: String) -> String {
        localizer.text(for: key) ?? Self.titleCase(slug)
    }

    /// Every `slug: "PF2E.Key"` pair in a TypeScript file, the first for each slug.
    static func keys(in file: URL) -> [String: String] {
        guard let source = try? String(contentsOf: file, encoding: .utf8) else { return [:] }
        let pattern = /(?:"([a-z0-9-]+)"|([a-z][a-z0-9]*))\s*:\s*\n?\s*"((?:PF2E|SF2E)\.[A-Za-z0-9.]+)"/
        var keys: [String: String] = [:]
        for match in source.matches(of: pattern) {
            let slug = String(match.output.1 ?? match.output.2 ?? "")
            if keys[slug] == nil { keys[slug] = String(match.output.3) }
        }
        return keys
    }

    static func pascalCase(_ slug: String) -> String {
        slug.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    static func titleCase(_ slug: String) -> String {
        slug.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
