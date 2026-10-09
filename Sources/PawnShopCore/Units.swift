import CoreGraphics

/// PDF user space has 72 points per inch.
public let pointsPerInch: CGFloat = 72

public extension CGFloat {
    /// This many inches, in points.
    static func inches(_ inches: CGFloat) -> CGFloat { inches * pointsPerInch }

    /// This many millimeters, in points.
    static func millimeters(_ millimeters: CGFloat) -> CGFloat { millimeters / 25.4 * pointsPerInch }

    /// This many points, in millimeters.
    var millimeters: CGFloat { self / pointsPerInch * 25.4 }
}
