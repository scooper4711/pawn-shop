import CoreGraphics
import CoreText
import Foundation

/// An item's description set in a card's text area: `**bold**`, `*italic*`, `---` as a thin rule, and ◆ ◆◆ ◆◆◆ ⤾
/// ◇ as the Pathfinder action icons, as large as fits from `largestSize` down to `smallestSize`, and cut short
/// with "…" when even that is too long.
struct ItemCardText {
    static let largestSize: CGFloat = 8
    static let smallestSize: CGFloat = 5.5
    static let sizeStep: CGFloat = 0.25
    /// Marks the paragraph standing for a rule, which `draw` strokes across the text.
    static let ruleKey = NSAttributedString.Key("PawnShopItemCardRule")

    /// The action glyphs and the characters Paizo's Pathfinder-Icons font draws them with: its private-use code
    /// points, the same as Tabletop Kit's `ActionIcons`, which this module doesn't depend on.
    static let actionGlyphs: [(String, String)] = [("◆◆◆", "\u{E900}"), ("◆◆", "\u{E901}"), ("◆", "\u{E902}"),
                                                   ("⤾", "\u{E904}"), ("↺", "\u{E904}"), ("◇", "\u{E903}")]
    /// The icons' size relative to the text: they fill more of their em than the pf2e action font they replace.
    static let actionScale: CGFloat = 0.88
    /// Lowers the icons, as a fraction of the text size, to sit on the line where the pf2e font's did.
    static let actionBaselineShift: CGFloat = -0.068

    let markup: String
    let ink: CGColor
    /// The action icons' font (see `ItemCardFonts.actions`); nil leaves the glyphs as text.
    var actionFont: CTFontDescriptor?

    /// Draws the text at the top of `rect`, with its rules in `ruleColor`.
    func draw(in rect: CGRect, ruleColor: CGColor, context: CGContext) {
        let frame = fittedFrame(in: rect)
        context.saveGState()
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        drawRules(of: frame, in: rect, color: ruleColor, context: context)
        context.restoreGState()
    }

    /// The text at the largest size that fits; at the smallest, cut short to fit.
    func fittedFrame(in rect: CGRect) -> CTFrame {
        var size = Self.largestSize
        while size > Self.smallestSize, !fits(attributed(size: size), in: rect) {
            size -= Self.sizeStep
        }
        var text = attributed(size: max(size, Self.smallestSize))
        if !fits(text, in: rect) { text = truncated(text, toFit: rect) }
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        return CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: rect, transform: nil), nil)
    }

    /// The markup as attributed text at `size` points.
    func attributed(size: CGFloat) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let paragraphs = markup.split(separator: "\n", omittingEmptySubsequences: true)
        for (index, paragraph) in paragraphs.enumerated() {
            let ending = index == paragraphs.count - 1 ? "" : "\n"
            if paragraph == "---" {
                text.append(NSAttributedString(string: "\u{00A0}" + ending, attributes: ruleAttributes(size: size)))
            } else {
                text.append(runs(of: String(paragraph) + ending, size: size))
            }
        }
        return text
    }

    private func runs(of paragraph: String, size: CGFloat) -> NSAttributedString {
        let text = NSMutableAttributedString()
        var emphasis = ItemCardFonts.Emphasis.plain
        var rest = Substring(paragraph)
        while !rest.isEmpty {
            if rest.hasPrefix("**") {
                emphasis = emphasis == .bold ? .plain : .bold
                rest = rest.dropFirst(2)
            } else if rest.hasPrefix("*") {
                emphasis = emphasis == .italic ? .plain : .italic
                rest = rest.dropFirst()
            } else if let (glyph, letter) = actionFont.flatMap({ _ in
                Self.actionGlyphs.first { rest.hasPrefix($0.0) }
            }) {
                text.append(NSAttributedString(string: letter, attributes: actionAttributes(size: size)))
                rest = rest.dropFirst(glyph.count)
            } else {
                let end = rest.dropFirst().firstIndex { $0 == "*" || Self.startsAction($0) } ?? rest.endIndex
                text.append(NSAttributedString(string: String(rest[..<end]),
                                               attributes: attributes(size: size, emphasis: emphasis)))
                rest = rest[end...]
            }
        }
        return text
    }

    private static func startsAction(_ character: Character) -> Bool {
        actionGlyphs.contains { $0.0.first == character }
    }

    private func attributes(size: CGFloat, emphasis: ItemCardFonts.Emphasis) -> [NSAttributedString.Key: Any] {
        [.init(kCTFontAttributeName as String): ItemCardFonts.body(size: size, emphasis: emphasis),
         .init(kCTForegroundColorAttributeName as String): ink,
         .init(kCTParagraphStyleAttributeName as String): Self.paragraphStyle(spacing: size * 0.3)]
    }

    private func actionAttributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
        var attributes = attributes(size: size, emphasis: .plain)
        if let actionFont {
            attributes[.init(kCTFontAttributeName as String)] =
                CTFontCreateWithFontDescriptor(actionFont, size * Self.actionScale, nil)
            attributes[.init(kCTBaselineOffsetAttributeName as String)] = size * Self.actionBaselineShift
        }
        return attributes
    }

    private static func paragraphStyle(spacing: CGFloat) -> CTParagraphStyle {
        var spacing = spacing
        return withUnsafeBytes(of: &spacing) { bytes in
            var setting = CTParagraphStyleSetting(spec: .paragraphSpacing, valueSize: MemoryLayout<CGFloat>.size,
                                                  value: bytes.baseAddress!)
            return CTParagraphStyleCreate(&setting, 1)
        }
    }

    private func ruleAttributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
        var attributes = attributes(size: size * 0.5, emphasis: .plain)
        attributes[Self.ruleKey] = true
        return attributes
    }

    private func fits(_ text: NSAttributedString, in rect: CGRect) -> Bool {
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let constraints = CGSize(width: rect.width, height: .greatestFiniteMagnitude)
        let needed = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, constraints, nil)
        return needed.height <= rect.height
    }

    /// The text cut at the last word that fits, followed by "…".
    private func truncated(_ text: NSAttributedString, toFit rect: CGRect) -> NSAttributedString {
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var visible = CFRange()
        CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, rect.size, &visible)
        let string = text.string as NSString
        let searched = NSRange(location: 0, length: max(0, visible.length - 1))
        let space = string.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards, range: searched)
        let length = space.location == NSNotFound ? searched.length : space.location
        let cut = NSMutableAttributedString(attributedString: text.attributedSubstring(
            from: NSRange(location: 0, length: length)))
        let ellipsis = cut.length > 0 ? cut.attributes(at: cut.length - 1, effectiveRange: nil) : [:]
        cut.append(NSAttributedString(string: "…", attributes: ellipsis))
        return cut
    }

    private func drawRules(of frame: CTFrame, in rect: CGRect, color: CGColor, context: CGContext) {
        guard let lines = CTFrameGetLines(frame) as? [CTLine], !lines.isEmpty else { return }
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(), &origins)
        context.setStrokeColor(color)
        context.setLineWidth(0.5)
        for (line, origin) in zip(lines, origins) where isRule(line) {
            context.move(to: CGPoint(x: rect.minX, y: rect.minY + origin.y + 1))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + origin.y + 1))
        }
        context.strokePath()
    }

    private func isRule(_ line: CTLine) -> Bool {
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        return runs.contains { run in
            (CTRunGetAttributes(run) as NSDictionary)[Self.ruleKey] != nil
        }
    }
}

/// The cards' typefaces: Palatino, as close to the books' as a Mac has, falling back to Times.
enum ItemCardFonts {
    enum Emphasis {
        case plain, bold, italic
    }

    static func body(size: CGFloat, emphasis: Emphasis) -> CTFont {
        switch emphasis {
        case .plain: font("Palatino-Roman", fallback: "Times-Roman", size: size)
        case .bold: font("Palatino-Bold", fallback: "Times-Bold", size: size)
        case .italic: font("Palatino-Italic", fallback: "Times-Italic", size: size)
        }
    }

    /// The action icons' font file, which `make items` copies unaltered from the private `Artwork` submodule.
    static let actionsFile = "Fonts/Pathfinder-Icons.ttf"

    /// Paizo's Pathfinder-Icons font, from a `Fonts` folder in `generated`; nil when it isn't there.
    static func actions(in generated: URL?) -> CTFontDescriptor? {
        guard let file = generated?.appendingPathComponent(actionsFile) else { return nil }
        return (CTFontManagerCreateFontDescriptorsFromURL(file as CFURL) as? [CTFontDescriptor])?.first
    }

    private static func font(_ name: String, fallback: String, size: CGFloat) -> CTFont {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let found = CTFontCopyPostScriptName(font) as String == name
        return found ? font : CTFontCreateWithName(fallback as CFString, size, nil)
    }
}
