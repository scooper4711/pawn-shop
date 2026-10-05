import CoreGraphics
import Foundation
import AppKit
import PDFKit

/// A stretch of text printed in one font size.
struct LabelRun: Equatable {
    let text: String
    let fontSize: CGFloat
}

/// Reads the text printed inside an area of a page.
protocol LabelReader {
    func runs(onPage pageIndex: Int, in rect: CGRect) -> [LabelRun]
}

/// Reads labels with PDFKit.
struct PDFKitLabelReader: LabelReader {
    let document: PDFDocument

    func runs(onPage pageIndex: Int, in rect: CGRect) -> [LabelRun] {
        guard let text = document.page(at: pageIndex)?.selection(for: rect)?.attributedString else { return [] }
        var runs: [LabelRun] = []
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { font, range, _ in
            let size = (font as? NSFont)?.pointSize ?? 0
            runs.append(LabelRun(text: (text.string as NSString).substring(with: range), fontSize: size))
        }
        return runs
    }
}

/// Turns the text printed in a pawn's foot into its name.
enum PawnLabel {
    private static let minorWords: Set<String> = ["a", "an", "and", "as", "at", "for", "in", "of", "on", "or",
                                                  "the", "to", "with"]

    /// Text this much smaller than the largest is fine print: the copyright line or a reference code.
    static let finePrintRatio: CGFloat = 0.8

    /// The name in a pawn's label: its largest text, with lines joined, spacing collapsed and title case.
    static func name(from runs: [LabelRun]) -> String {
        let largest = runs.map(\.fontSize).max() ?? 0
        let text = runs.filter { $0.fontSize >= largest * finePrintRatio }.map(\.text).joined(separator: " ")
        let withoutCopyright = text.replacingOccurrences(of: "©[^\n]*", with: " ", options: .regularExpression)
        let words = undoubled(withoutCopyright).split(whereSeparator: \.isWhitespace).map(String.init)
        return titleCase(words).trimmingCharacters(in: CharacterSet(charactersIn: ",;: "))
    }

    /// Text shorter than this is never treated as doubled, so a name such as "Mimi" is left alone.
    static let shortestDoubled = 10

    /// Some labels are drawn twice (a fill and an outline), so each chunk of text is read twice in a row:
    /// "ALGHOLLTHU, U ALGHOLLTHU, UGOTHOL GOTHOL". This keeps one copy of each chunk, with the spacing that
    /// followed the chunk's second copy. Text that is not doubled throughout is returned unchanged.
    static func undoubled(_ text: String) -> String {
        let characters = Array(text)
        let letters = characters.indices.filter { !characters[$0].isWhitespace }
        guard letters.count >= shortestDoubled, let chunks = doubledChunks(letters.map { characters[$0] }, from: 0)
        else { return text }
        var result = ""
        var position = 0
        for length in chunks {
            let firstCopy = letters[position]...letters[position + length - 1]
            let afterSecondCopy = letters[position + 2 * length - 1] + 1
            let next = position + 2 * length < letters.count ? letters[position + 2 * length] : characters.count
            result += String(characters[firstCopy]) + String(characters[afterSecondCopy..<next])
            position += 2 * length
        }
        return result
    }

    /// Chunk lengths that split `letters` from `start` into chunks each repeated once, longest chunks first.
    private static func doubledChunks(_ letters: [Character], from start: Int) -> [Int]? {
        if start == letters.count { return [] }
        for length in stride(from: (letters.count - start) / 2, through: 1, by: -1)
        where letters[start..<start + length] == letters[start + length..<start + 2 * length] {
            if let rest = doubledChunks(letters, from: start + 2 * length) { return [length] + rest }
        }
        return nil
    }

    /// Paizo prints names in capitals; this restores ordinary capitalization, keeping minor words lowercase.
    static func titleCase(_ words: [String]) -> String {
        words.enumerated().map { index, word in
            let lower = word.lowercased()
            if index > 0, minorWords.contains(lower) { return lower }
            return capitalized(lower)
        }.joined(separator: " ")
    }

    /// Capitalizes each part of a word split by hyphens, keeping leading punctuation such as quotes.
    private static func capitalized(_ word: String) -> String {
        word.split(separator: "-", omittingEmptySubsequences: false).map { part -> String in
            guard let first = part.firstIndex(where: \.isLetter) else { return String(part) }
            return part[..<first] + part[first].uppercased() + part[part.index(after: first)...]
        }.joined(separator: "-")
    }
}
