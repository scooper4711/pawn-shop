import CoreGraphics

/// An arrow key's step through a grid.
public enum GridMove: Sendable {
    case left, right, up, down
}

/// Moves a selection through a grid filled row by row, as Finder does.
public enum GridNavigation {
    /// Where `move` lands from `index` in a grid of `count` items `columns` wide. It stays put at the edges,
    /// except that moving down onto a shorter last row lands on its last item.
    public static func index(after move: GridMove, from index: Int, count: Int, columns: Int) -> Int {
        guard count > 0 else { return 0 }
        let columns = max(1, columns)
        let index = min(max(0, index), count - 1)
        switch move {
        case .left: return max(0, index - 1)
        case .right: return min(count - 1, index + 1)
        case .up: return index - columns >= 0 ? index - columns : index
        case .down:
            if index + columns < count { return index + columns }
            let isOnLastRow = index / columns == (count - 1) / columns
            return isOnLastRow ? index : count - 1
        }
    }

    /// How many columns an adaptive grid fits across `width`: as many items of at least `minimum` as fit with
    /// `spacing` between them.
    public static func columns(fitting width: CGFloat, minimum: CGFloat, spacing: CGFloat) -> Int {
        guard minimum + spacing > 0 else { return 1 }
        return max(1, Int(((width + spacing) / (minimum + spacing)).rounded(.down)))
    }
}
