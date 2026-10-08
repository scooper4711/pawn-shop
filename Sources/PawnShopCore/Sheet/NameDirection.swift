import CoreGraphics
import PDFKit

/// Which way a pawn's printed words read. Paizo turns art that doesn't fit upright, such as a long starship, on
/// its side and prints the name along it, so the words show which way up the art is meant to be seen.
enum NameDirection {
    /// The quarter turns clockwise that make words reading along `direction` (y up) read left to right.
    static func clockwiseQuarterTurns(toLevel direction: CGVector) -> Int {
        guard direction != .zero else { return 0 }
        if abs(direction.dx) >= abs(direction.dy) { return direction.dx >= 0 ? 0 : 2 }
        return direction.dy > 0 ? 1 : 3
    }

    /// The way the longest line of words inside `rect` reads, on the page; zero when there are no words.
    /// Every line printed on a pawn runs the same way, and the longest gives the steadiest answer.
    static func readingDirection(on page: PDFPage, inside rect: CGRect) -> CGVector {
        guard let lines = page.selection(for: rect)?.selectionsByLine(),
              let longest = lines.max(by: { ($0.string?.count ?? 0) < ($1.string?.count ?? 0) })
        else { return .zero }
        let bounds = longest.bounds(for: page).insetBy(dx: -1, dy: -1)
        // Each letter's own selection, as `characterBounds(at:)` places turned letters as if they weren't.
        let centers = (0..<page.numberOfCharacters)
            .compactMap { page.selection(for: NSRange(location: $0, length: 1))?.bounds(for: page) }
            .filter { !$0.isEmpty && bounds.contains(CGPoint(x: $0.midX, y: $0.midY)) }
            .map { CGPoint(x: $0.midX, y: $0.midY) }
        guard let first = centers.first, let last = centers.last else { return .zero }
        return CGVector(dx: last.x - first.x, dy: last.y - first.y)
    }
}

extension CGVector {
    /// The vector moved by `transform`, ignoring its translation.
    func applying(_ transform: CGAffineTransform) -> CGVector {
        CGVector(dx: dx * transform.a + dy * transform.c, dy: dx * transform.b + dy * transform.d)
    }
}

extension CGImage {
    /// The image turned clockwise by `turns` quarter turns; itself when `turns` is a whole turn.
    func rotated(clockwiseQuarterTurns turns: Int) -> CGImage? {
        let turns = (turns % 4 + 4) % 4
        guard turns != 0 else { return self }
        let sideways = turns != 2
        let size = sideways ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Clockwise on screen, where y points up, is a negative angle about the new image's matching corner.
        switch turns {
        case 1: context.translateBy(x: 0, y: size.height)
        case 2: context.translateBy(x: size.width, y: size.height)
        default: context.translateBy(x: size.width, y: 0)
        }
        context.rotate(by: -CGFloat(turns) * .pi / 2)
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
