import Foundation

/// What a Battle Card's stat side says about its creature: its name, its size as a pawn, and its traits.
struct CardStats: Equatable {
    var name: String
    var size: PawnSize
    /// Lowercase, in the order printed: "tiny", "aeon", "monitor". Rarity and alignment are left out.
    var traits: [String]

    /// Traits that say how rare a creature is, or its alignment, rather than what it is.
    static let ignoredTraits: Set<String> = ["common", "uncommon", "rare", "unique",
                                             "lg", "ng", "cg", "ln", "n", "cn", "le", "ne", "ce"]
    /// Words of the trait line that text read out of order can put next to the name: rarity, alignment, size.
    private static let strayTraits = Set(ignoredTraits.map { $0.uppercased() })
        .union(["TINY", "SMALL", "MEDIUM", "LARGE", "HUGE", "GARGANTUAN"])
    /// How many lines above its header a name may be printed.
    private static let nameLinesAbove = 3

    /// Reads a Pathfinder card ("AEON, ARBITER CREATURE 1", then its traits in capitals up to Perception) or a
    /// Starfinder one ("AEON GUARD CR 3", then a line such as "LE Medium humanoid (human)"). Nil for a page that
    /// isn't a creature's stat side: a hazard, a stat block continued from another card, rules or a title page.
    static func read(_ text: String) -> CardStats? {
        // Tabs and the backspaces some cards print after the name separate words.
        let scalars = text.unicodeScalars.map { scalar in
            scalar != "\n" && CharacterSet.controlCharacters.contains(scalar) ? " " : scalar
        }
        let cleaned = String(String.UnicodeScalarView(scalars))
        guard cleaned.range(of: #"\(.*continued from card"#, options: .regularExpression) == nil else { return nil }
        return readPathfinder(cleaned) ?? readStarfinder(cleaned)
    }

    private static func readPathfinder(_ text: String) -> CardStats? {
        guard let header = text.range(of: #"\bCREATURE\s+[-–−]?\d+"#, options: .regularExpression),
              let (name, strays) = name(before: header, in: text)
        else { return nil }
        let rest = text[header.upperBound...]
        let traitText = rest.range(of: "Perception").map { rest[..<$0.lowerBound] } ?? rest
        let traits = strays + traitText.split(whereSeparator: \.isWhitespace).map(String.init)
            .filter { $0.range(of: #"^[A-Z][A-Z'’-]*$"#, options: .regularExpression) != nil }
        let size = traits.lazy.compactMap { PawnSize.creature($0) }.first ?? .medium
        return CardStats(name: name, size: size, traits: kept(traits))
    }

    /// The name comes before "CR n", or before "XP n" where the challenge rating is printed further down. The
    /// size, type and subtypes follow on a line such as "N Medium outsider (aeon, extraplanar)".
    private static func readStarfinder(_ text: String) -> CardStats? {
        guard let header = text.range(of: #"\b(CR\s+\d+(/\d+)?|XP\s+[\d,]+)\b"#, options: .regularExpression),
              let (name, _) = name(before: header, in: text)
        else { return nil }
        let sizes = "Fine|Diminutive|Tiny|Small|Medium|Large|Huge|Gargantuan|Colossal"
        let pattern = #"(?m)\b(?:[LNC][GNE]? )?("# + sizes + #") ([a-z][a-z ]*?) *(?:\(([^)]*)\))? *$"#
        guard let line = try? NSRegularExpression(pattern: pattern)
            .firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return CardStats(name: name, size: .medium, traits: []) }
        let group = { (index: Int) in Range(line.range(at: index), in: text).map { String(text[$0]) } ?? "" }
        // Subtypes may carry a book reference: "(technological; Starfinder Pact Worlds 196)".
        let subtypes = group(3).split(separator: ";").first.map { $0.split(separator: ",") } ?? []
        return CardStats(name: name, size: PawnSize.creature(group(1)) ?? .medium,
                         traits: kept([group(1), group(2)] + subtypes.map(String.init)))
    }

    /// The name in title case: the words in capitals that start the header's line or, when there are none, one
    /// of the lines just above it. Trait words that came out of order beside it are returned apart. Nil when
    /// no name is found.
    private static func name(before header: Range<String.Index>, in text: String) -> (String, [String])? {
        let lines = text[..<header.lowerBound].split(separator: "\n", omittingEmptySubsequences: false)
        guard var words = lines.suffix(nameLinesAbove + 1).reversed().lazy.map(capitalWords).first(where: {
            !$0.isEmpty
        }) else { return nil }
        var strays: [String] = []
        while words.count > 1, strayTraits.contains(words[0]) { strays.append(words.removeFirst()) }
        // A size or rarity after a comma is part of the name: "HERD ANIMAL, HUGE", "SWAMP STRIDER, COMMON".
        while words.count > 1, let last = words.last, strayTraits.contains(last),
              !words[words.count - 2].hasSuffix(",") {
            strays.append(words.removeLast())
        }
        return (PawnLabel.titleCase(words), strays)
    }

    /// The words at the start of a line that are in capitals, as card names are printed.
    private static func capitalWords(_ line: Substring) -> [String] {
        Array(line.split(whereSeparator: \.isWhitespace).prefix { word in
            word.contains(where: \.isLetter) && !word.contains(where: \.isLowercase)
        }.map(String.init))
    }

    /// The traits lowercased and trimmed, once each, without rarity and alignment.
    private static func kept(_ traits: [String]) -> [String] {
        var kept: [String] = []
        for trait in traits.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() })
        where !trait.isEmpty && !ignoredTraits.contains(trait) && !kept.contains(trait) {
            kept.append(trait)
        }
        return kept
    }
}

extension PawnSize {
    /// The pawn for a creature of a size printed on its card: creatures up to medium stand on medium pawns,
    /// and colossal ones on gargantuan pawns. Nil for a word that isn't a size.
    static func creature(_ size: String) -> PawnSize? {
        switch size.lowercased() {
        case "fine", "diminutive", "tiny", "small", "medium": .medium
        case "large": .large
        case "huge": .huge
        case "gargantuan", "colossal": .gargantuan
        default: nil
        }
    }
}
