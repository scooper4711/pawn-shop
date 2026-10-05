import CoreGraphics

/// PDF user space has 72 points per inch.
public let pointsPerInch: CGFloat = 72

public extension CGFloat {
    /// This many inches, in points.
    static func inches(_ inches: CGFloat) -> CGFloat { inches * pointsPerInch }
}
