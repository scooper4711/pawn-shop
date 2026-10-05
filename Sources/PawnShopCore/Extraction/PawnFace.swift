import CoreGraphics

/// One side of a pawn: an area of a PDF page, and how to turn it upright.
public struct PawnFace: Codable, Hashable, Sendable {
    /// Zero-based page index in the source PDF.
    public var pageIndex: Int
    /// The face's bounds in PDF page space.
    public var rect: CGRect
    /// Degrees counterclockwise that turn the head to the top: 0, 90, 180 or 270.
    public var rotation: Int
    /// True when the face is drawn flipped left to right (a back made from its front).
    public var mirrored: Bool

    public init(pageIndex: Int, rect: CGRect, rotation: Int, mirrored: Bool = false) {
        self.pageIndex = pageIndex
        self.rect = rect
        self.rotation = rotation
        self.mirrored = mirrored
    }

    /// The face's size once upright.
    public var uprightSize: CGSize {
        rotation % 180 == 0 ? rect.size : CGSize(width: rect.height, height: rect.width)
    }

    /// The same face flipped left to right.
    public func mirroredCopy() -> PawnFace {
        PawnFace(pageIndex: pageIndex, rect: rect, rotation: rotation, mirrored: !mirrored)
    }

    /// Maps page space so that the face fills `destination` upright.
    public func transform(into destination: CGRect) -> CGAffineTransform {
        let upright = uprightSize
        let scale = CGAffineTransform(scaleX: destination.width / upright.width * (mirrored ? -1 : 1),
                                      y: destination.height / upright.height)
        return CGAffineTransform(translationX: -rect.midX, y: -rect.midY)
            .concatenating(CGAffineTransform(rotationAngle: CGFloat(rotation) * .pi / 180))
            .concatenating(scale)
            .concatenating(CGAffineTransform(translationX: destination.midX, y: destination.midY))
    }
}
