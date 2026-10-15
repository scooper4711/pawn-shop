import CoreGraphics
import CoreText
import Foundation

/// One card of an item's set: the part of the description it prints, and at what size.
public struct ItemCardPage: Hashable, Sendable {
    /// Paragraphs on lines of their own, in the description's markup.
    public var markup: String
    public var size: CGFloat
}

/// Splits an item's description over as few cards as it needs (R8.3.1): one at the standard size, or a little
/// smaller when that is all it takes, or else continued over more cards.
enum ItemCardLayout {
    static let standardSize: CGFloat = 7
    /// How far text may shrink unless the user chooses otherwise.
    static let defaultSmallestSize: CGFloat = 6.25
    /// The smallest sizes a user may choose.
    static let smallestSizes: ClosedRange<CGFloat> = 5.5...6.5
    static let sizeStep: CGFloat = 0.25

    /// Sizes to try, after the standard one, for text that nearly fits: a quarter point at a time down to
    /// `smallest`.
    static func smallerSizes(downTo smallest: CGFloat) -> [CGFloat] {
        let floor = min(max(smallest, smallestSizes.lowerBound), standardSize)
        return Array(stride(from: standardSize - sizeStep, through: floor, by: -sizeStep))
    }
    /// A paragraph that doesn't fit moves whole to the next card unless more of the card than this would stay
    /// empty; then it is split between lines.
    static let emptyShareToSplit: CGFloat = 1.0 / 3

    /// The item's cards, in order, with text no smaller than `smallestSize`.
    static func cards(for item: CatalogItem, actionFont: CTFontDescriptor?,
                      smallestSize: CGFloat = defaultSmallestSize) -> [ItemCardPage] {
        let smallerSizes = smallerSizes(downTo: smallestSize)
        let geometry = ItemCardGeometry(item: item, actionFont: actionFont)
        let pager = CardPager(first: geometry.textRect(isFirstCard: true),
                              next: geometry.textRect(isFirstCard: false), actionFont: actionFont)
        let paragraphs = item.description.split(separator: "\n").map(String.init)
        for size in [standardSize] + smallerSizes where pager.fits(paragraphs, isFirstCard: true, size: size) {
            return [ItemCardPage(markup: paragraphs.joined(separator: "\n"), size: size)]
        }
        let standard = pager.pages(paragraphs, size: standardSize)
        let smaller = smallerSizes.lazy.map { pager.pages(paragraphs, size: $0) }.first { $0.count < standard.count }
        return smaller ?? standard
    }
}

/// Fills cards with paragraphs at one size.
struct CardPager {
    let first: CGRect
    let next: CGRect
    let actionFont: CTFontDescriptor?

    func fits(_ paragraphs: [String], isFirstCard: Bool, size: CGFloat) -> Bool {
        height(paragraphs, size: size) <= rect(isFirstCard: isFirstCard).height
    }

    /// The paragraphs over as many cards as they take.
    func pages(_ paragraphs: [String], size: CGFloat) -> [ItemCardPage] {
        var cards: [[String]] = [[]]
        var queue = paragraphs[...]
        while let paragraph = queue.first {
            let isFirstCard = cards.count == 1
            let current = cards[cards.count - 1]
            if paragraph == "---", current.isEmpty, !isFirstCard {
                queue.removeFirst()
            } else if fits(current + [paragraph], isFirstCard: isFirstCard, size: size) {
                cards[cards.count - 1].append(paragraph)
                queue.removeFirst()
            } else if shouldSplit(paragraph, after: current, isFirstCard: isFirstCard, size: size),
                      let (head, tail) = split(paragraph, after: current, isFirstCard: isFirstCard, size: size) {
                cards[cards.count - 1].append(head)
                queue[queue.startIndex] = tail
                cards.append([])
            } else if current.isEmpty {
                // Not a word of it fits an empty card; it goes on one anyway, rather than on none.
                cards[cards.count - 1].append(paragraph)
                queue.removeFirst()
            } else {
                cards.append([])
            }
        }
        return cards.map(Self.trimmed).filter { !$0.isEmpty }
            .map { ItemCardPage(markup: $0.joined(separator: "\n"), size: size) }
    }

    /// Whether a paragraph that doesn't fit is split here rather than moved whole: when it is alone, when moving
    /// it would leave much of the card empty, or when it wouldn't fit the next card either. A Heightened entry
    /// is only split when it is alone.
    private func shouldSplit(_ paragraph: String, after current: [String], isFirstCard: Bool,
                             size: CGFloat) -> Bool {
        guard !current.isEmpty else { return true }
        guard !paragraph.hasPrefix("**Heightened") else { return false }
        let room = rect(isFirstCard: isFirstCard).height
        let empty = (room - height(current, size: size)) / room
        return empty > ItemCardLayout.emptyShareToSplit || !fits([paragraph], isFirstCard: false, size: size)
    }

    /// The most words of `paragraph` that fit after `current`, and the rest; nil when not even one does.
    private func split(_ paragraph: String, after current: [String], isFirstCard: Bool,
                       size: CGFloat) -> (head: String, tail: String)? {
        let words = paragraph.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        var low = 0, high = words.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            let head = MarkupSplit(words: words, count: middle).head
            if fits(current + [head], isFirstCard: isFirstCard, size: size) { low = middle } else { high = middle - 1 }
        }
        guard low > 0 else { return nil }
        let parts = MarkupSplit(words: words, count: low)
        return (parts.head, parts.tail)
    }

    private func rect(isFirstCard: Bool) -> CGRect { isFirstCard ? first : next }

    private func height(_ paragraphs: [String], size: CGFloat) -> CGFloat {
        ItemCardText(markup: paragraphs.joined(separator: "\n"), ink: CGColor(gray: 0, alpha: 1),
                     actionFont: actionFont).height(size: size, width: first.width)
    }

    /// A card's paragraphs without a rule at either end.
    private static func trimmed(_ paragraphs: [String]) -> [String] {
        var paragraphs = paragraphs[...]
        while paragraphs.first == "---" { paragraphs.removeFirst() }
        while paragraphs.last == "---" { paragraphs.removeLast() }
        return Array(paragraphs)
    }
}

/// A paragraph split after its first `count` words, with emphasis closed at the end of the head and opened again
/// at the start of the tail, so `**Heightened (+2)** The…` split inside the bold stays bold on both cards.
struct MarkupSplit {
    let head: String
    let tail: String

    init(words: [String], count: Int) {
        var head = words.prefix(count).joined(separator: " ")
        var tail = words.dropFirst(count).joined(separator: " ")
        let bold = head.components(separatedBy: "**").count - 1
        let italic = head.replacingOccurrences(of: "**", with: "").filter { $0 == "*" }.count
        if italic % 2 == 1 {
            head += "*"
            tail = "*" + tail
        }
        if bold % 2 == 1 {
            head += "**"
            tail = "**" + tail
        }
        self.head = head
        self.tail = tail
    }
}
