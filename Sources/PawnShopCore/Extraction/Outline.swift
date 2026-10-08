import CoreGraphics

/// A side of a rectangle.
public enum Edge: String, Codable, Sendable {
    case top, bottom, left, right
}

/// A pawn's cut outline on a page: straight edges with two rounded corners at the head.
public struct Outline: Equatable, Sendable {
    /// Bounds in PDF page space (origin bottom left).
    public let rect: CGRect
    /// The edge with the rounded corners, where the pawn's head is.
    public let headEdge: Edge

    public init(rect: CGRect, headEdge: Edge) {
        self.rect = rect
        self.headEdge = headEdge
    }

    /// Degrees counterclockwise that turn the head to the top: 0, 90, 180 or 270.
    public var uprightRotation: Int {
        switch headEdge {
        case .top: 0
        case .right: 90
        case .bottom: 180
        case .left: 270
        }
    }

    /// The outline's size once turned upright.
    public var uprightSize: CGSize {
        switch headEdge {
        case .top, .bottom: rect.size
        case .left, .right: CGSize(width: rect.height, height: rect.width)
        }
    }

    /// The pawn size this outline matches, if any.
    public var size: PawnSize? { PawnSize.classify(uprightSize) }
}

/// A subpath built from content-stream path operators, in page space.
struct Subpath {
    private(set) var points: [CGPoint] = []
    /// Midpoints of the curve segments' end points.
    private(set) var curveMidpoints: [CGPoint] = []
    /// The points the path passes through: segment ends, without curve control points.
    private(set) var anchors: [CGPoint] = []

    var lastPoint: CGPoint? { points.last }

    mutating func add(line point: CGPoint) {
        points.append(point)
        anchors.append(point)
    }

    mutating func add(curveTo end: CGPoint, controls: [CGPoint]) {
        let start = points.last ?? end
        curveMidpoints.append(CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2))
        points.append(contentsOf: controls)
        points.append(end)
        anchors.append(end)
    }

    /// The circle this subpath draws, whole or with flat sides: at least `minimumCurves` curves, and every point
    /// it passes through on one circle.
    func circle() -> Circle? {
        guard curveMidpoints.count >= Self.minimumCurves else { return nil }
        return Circle.through(anchors)
    }

    /// A circle takes four curves; a token's clip cut flat on one side keeps three.
    static let minimumCurves = 3

    /// The outline this subpath draws, when it has exactly two curves at one edge.
    func outline() -> Outline? {
        guard curveMidpoints.count == 2, points.count >= 4 else { return nil }
        let rect = Self.bounds(of: points)
        guard rect.width > 1, rect.height > 1 else { return nil }
        return Outline(rect: rect, headEdge: Self.edge(nearest: curveMidpoints, in: rect))
    }

    static func bounds(of points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    /// The edge the points lean toward, measured from the center in units of the half sizes.
    static func edge(nearest points: [CGPoint], in rect: CGRect) -> Edge {
        let centerX = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let centerY = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        let horizontal = (centerX - rect.midX) / (rect.width / 2)
        let vertical = (centerY - rect.midY) / (rect.height / 2)
        if abs(vertical) >= abs(horizontal) {
            return vertical >= 0 ? .top : .bottom
        }
        return horizontal >= 0 ? .right : .left
    }
}
