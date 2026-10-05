import CoreGraphics
import Foundation

/// Strips of one sheet entry to place.
public struct LayoutItem: Equatable, Sendable {
    public var entryID: UUID
    /// The folded strip upright: the pawn's width by twice its height.
    public var stripSize: CGSize
    public var count: Int

    public init(entryID: UUID, stripSize: CGSize, count: Int) {
        self.entryID = entryID
        self.stripSize = stripSize
        self.count = count
    }

    /// The strip for a pawn of `upright` size: front below, back above.
    public static func stripSize(forPawn upright: CGSize) -> CGSize {
        CGSize(width: upright.width, height: upright.height * 2)
    }
}

/// A strip's place on a page.
public struct PlacedStrip: Equatable, Sendable {
    public var entryID: UUID
    /// Which copy of the entry, from 0.
    public var copy: Int
    /// The strip's area on the page, in page coordinates.
    public var rect: CGRect
    /// True when the strip lies on its side, its foot (front) to the left and its head (back) to the right.
    public var sideways: Bool
}

/// The strips of a sheet arranged on pages.
public struct SheetLayout: Equatable, Sendable {
    public var pages: [[PlacedStrip]]

    public init(pages: [[PlacedStrip]]) {
        self.pages = pages
    }

    /// Packs every copy into the printable area in rows, largest strips first, over as many pages as needed.
    /// Strips are laid out upright or sideways, whichever takes fewer pages; a strip that only fits the other
    /// way is turned.
    public static func arrange(_ items: [LayoutItem], settings: SheetSettings) -> SheetLayout {
        let upright = ShelfPacker(area: settings.paper.imageableRect, spacing: settings.cutStyle.spacing,
                                  sideways: false).pack(items)
        let sideways = ShelfPacker(area: settings.paper.imageableRect, spacing: settings.cutStyle.spacing,
                                   sideways: true).pack(items)
        return SheetLayout(pages: sideways.count < upright.count ? sideways : upright)
    }

    /// The strip at `point` on page `pageIndex`, if any.
    public func strip(at point: CGPoint, onPage pageIndex: Int) -> PlacedStrip? {
        guard pages.indices.contains(pageIndex) else { return nil }
        return pages[pageIndex].first { $0.rect.contains(point) }
    }
}

/// Fills rows from the top left of an area, starting a new row when one is full and a new page when the
/// area is full.
struct ShelfPacker {
    let area: CGRect
    let spacing: CGFloat
    /// The preferred orientation.
    let sideways: Bool

    private struct Cursor {
        var offset: CGFloat = 0
        var rowTop: CGFloat = 0
        var rowHeight: CGFloat = 0
    }

    func pack(_ items: [LayoutItem]) -> [[PlacedStrip]] {
        var pages: [[PlacedStrip]] = []
        var page: [PlacedStrip] = []
        var cursor = Cursor()
        for (item, copy) in copies(of: items) {
            let (size, turned) = orientation(of: item.stripSize)
            if cursor.offset > 0, cursor.offset + size.width > area.width {
                cursor = Cursor(offset: 0, rowTop: cursor.rowTop + cursor.rowHeight + spacing, rowHeight: 0)
            }
            if !page.isEmpty, cursor.rowTop + size.height > area.height {
                pages.append(page)
                page = []
                cursor = Cursor()
            }
            let origin = CGPoint(x: area.minX + cursor.offset, y: area.maxY - cursor.rowTop - size.height)
            page.append(PlacedStrip(entryID: item.entryID, copy: copy, rect: CGRect(origin: origin, size: size),
                                    sideways: turned))
            cursor.offset += size.width + spacing
            cursor.rowHeight = max(cursor.rowHeight, size.height)
        }
        if !page.isEmpty { pages.append(page) }
        return pages
    }

    /// The strip's size on the page and whether it is turned: the preferred way when it fits, else the other.
    private func orientation(of upright: CGSize) -> (CGSize, Bool) {
        let turned = CGSize(width: upright.height, height: upright.width)
        let preferred = sideways ? (turned, true) : (upright, false)
        let other = sideways ? (upright, false) : (turned, true)
        return fits(preferred.0) || !fits(other.0) ? preferred : other
    }

    private func fits(_ size: CGSize) -> Bool { size.width <= area.width && size.height <= area.height }

    /// Every copy, tallest strips first (then widest), keeping sheet order among equal sizes.
    private func copies(of items: [LayoutItem]) -> [(LayoutItem, Int)] {
        let ordered = items.enumerated().sorted { first, second in
            let firstSize = first.element.stripSize, secondSize = second.element.stripSize
            if firstSize.height != secondSize.height { return firstSize.height > secondSize.height }
            if firstSize.width != secondSize.width { return firstSize.width > secondSize.width }
            return first.offset < second.offset
        }
        return ordered.flatMap { _, item in (0..<max(0, item.count)).map { (item, $0) } }
    }
}
