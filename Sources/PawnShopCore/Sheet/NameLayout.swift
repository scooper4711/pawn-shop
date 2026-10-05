import CoreGraphics
import CoreText
import Foundation

/// How a custom pawn's name fits across its foot: one line at full size if it can, else two lines at full
/// size, and only then smaller type.
public struct NameLayout: Equatable {
    /// The smallest type worth printing, in points.
    static let smallestSize: CGFloat = 3
    static let sizeStep: CGFloat = 0.25

    public let lines: [String]
    public let fontSize: CGFloat

    /// Fits `name` within `width` starting from `fontSize`.
    public static func fit(_ name: String, width: CGFloat, fontSize: CGFloat) -> NameLayout {
        let words = name.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return NameLayout(lines: [], fontSize: fontSize) }
        let candidates = [[words.joined(separator: " ")]] + twoLineSplits(words)
        var size = fontSize
        while size > smallestSize {
            if let lines = candidates.first(where: { fits($0, width: width, size: size) }) {
                return NameLayout(lines: lines, fontSize: size)
            }
            size -= sizeStep
        }
        return NameLayout(lines: candidates.last ?? [], fontSize: smallestSize)
    }

    /// Every way to break the words onto two lines, the most even first.
    static func twoLineSplits(_ words: [String]) -> [[String]] {
        guard words.count > 1 else { return [] }
        return (1..<words.count).map { index in
            [words[..<index].joined(separator: " "), words[index...].joined(separator: " ")]
        }.sorted { abs($0[0].count - $0[1].count) < abs($1[0].count - $1[1].count) }
    }

    static func fits(_ lines: [String], width: CGFloat, size: CGFloat) -> Bool {
        lines.allSatisfy { textWidth($0, size: size) <= width }
    }

    static func textWidth(_ text: String, size: CGFloat) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(text, size: size), nil, nil, nil))
    }

    /// A line of bold black type.
    static func line(_ text: String, size: CGFloat) -> CTLine {
        let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [.init(kCTFontAttributeName as String): font,
                                                         .init(kCTForegroundColorAttributeName as String):
                                                            CGColor(gray: 0, alpha: 1)]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }
}
