import CoreGraphics

/// A pawn's size category, with the cut outline Paizo prints for it.
public enum PawnSize: String, Codable, CaseIterable, Sendable, Comparable {
    case small, medium, large, huge, gargantuan

    /// Outline sizes may differ from the table by this much and still match.
    static let tolerance: CGFloat = 4

    /// The upright outline: width across the base, height from base to head, in points.
    public var outlineSize: CGSize {
        switch self {
        case .small: CGSize(width: 60, height: 81)
        case .medium: CGSize(width: 81, height: 138)
        case .large: CGSize(width: 138, height: 180)
        case .huge: CGSize(width: 215, height: 281)
        // Paizo prints no gargantuan pawns; this extends the table one step for custom art.
        case .gargantuan: CGSize(width: 292, height: 382)
        }
    }

    public var displayName: String { rawValue.capitalized }

    /// The size whose outline matches `upright`, if any.
    public static func classify(_ upright: CGSize) -> PawnSize? {
        allCases.first { size in
            abs(size.outlineSize.width - upright.width) <= tolerance
                && abs(size.outlineSize.height - upright.height) <= tolerance
        }
    }

    public static func < (lhs: PawnSize, rhs: PawnSize) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
