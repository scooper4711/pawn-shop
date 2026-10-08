import CoreGraphics

/// A circle in PDF page space.
struct Circle: Equatable {
    let center: CGPoint
    let radius: CGFloat

    /// Points may lie this far from the radius, as a share of it, and still be on the circle.
    static let roundness: CGFloat = 0.03

    var diameter: CGFloat { radius * 2 }

    /// The square around the circle.
    var bounds: CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: diameter, height: diameter)
    }

    func contains(_ point: CGPoint) -> Bool {
        distance(from: point) <= radius
    }

    func distance(from point: CGPoint) -> CGFloat {
        hypot(point.x - center.x, point.y - center.y)
    }

    /// The same circle with the radius shortened by `amount`.
    func inset(by amount: CGFloat) -> Circle {
        Circle(center: center, radius: radius - amount)
    }

    /// True when both circles have the same center and size, within `tolerance` points.
    func isSame(as other: Circle, tolerance: CGFloat) -> Bool {
        distance(from: other.center) <= tolerance && abs(radius - other.radius) <= tolerance
    }

    /// The circle through `points` when they all lie on one, fitted by least squares; nil when they don't.
    /// Points on a part of a circle, such as a circle with a flat side, give the whole circle.
    static func through(_ points: [CGPoint]) -> Circle? {
        guard points.count >= 3, let circle = leastSquares(points), circle.radius > 1,
              points.allSatisfy({ abs(circle.distance(from: $0) - circle.radius) <= circle.radius * roundness })
        else { return nil }
        return circle
    }

    /// Solves x² + y² + Dx + Ey + F = 0 for D, E and F (Kåsa's fit).
    private static func leastSquares(_ points: [CGPoint]) -> Circle? {
        var matrix = [[CGFloat]](repeating: [0, 0, 0], count: 3)
        var vector: [CGFloat] = [0, 0, 0]
        for point in points {
            let row: [CGFloat] = [point.x, point.y, 1]
            let target = -(point.x * point.x + point.y * point.y)
            for column in 0..<3 {
                vector[column] += row[column] * target
                for other in 0..<3 { matrix[column][other] += row[column] * row[other] }
            }
        }
        guard let solution = solve(matrix, vector) else { return nil }
        let center = CGPoint(x: -solution[0] / 2, y: -solution[1] / 2)
        let squared = center.x * center.x + center.y * center.y - solution[2]
        return squared > 0 ? Circle(center: center, radius: squared.squareRoot()) : nil
    }

    /// Cramer's rule for three equations.
    private static func solve(_ matrix: [[CGFloat]], _ vector: [CGFloat]) -> [CGFloat]? {
        let base = determinant(matrix)
        guard abs(base) > 1e-9 else { return nil }
        return (0..<3).map { column in
            var replaced = matrix
            for row in 0..<3 { replaced[row][column] = vector[row] }
            return determinant(replaced) / base
        }
    }

    private static func determinant(_ matrix: [[CGFloat]]) -> CGFloat {
        matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1])
            - matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0])
            + matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0])
    }
}
