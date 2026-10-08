import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

/// A PDF stream object holding `content`.
func streamObject(_ content: String) -> String {
    "<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream"
}

@Suite struct CircleTests {
    func points(on circle: Circle, angles: [CGFloat]) -> [CGPoint] {
        angles.map {
            CGPoint(x: circle.center.x + circle.radius * cos($0), y: circle.center.y + circle.radius * sin($0))
        }
    }

    @Test func fitsTheCircleThroughPointsOnIt() throws {
        let circle = Circle(center: CGPoint(x: 120, y: 340), radius: 45)
        let fitted = try #require(Circle.through(points(on: circle, angles: [0, 1, 2, 3, 4, 5])))
        #expect(fitted.isSame(as: circle, tolerance: 0.01))
        #expect(abs(fitted.bounds.minX - 75) < 0.01 && abs(fitted.bounds.minY - 295) < 0.01)
        #expect(abs(fitted.diameter - 90) < 0.01)
        #expect(fitted.contains(CGPoint(x: 120, y: 380)) && !fitted.contains(CGPoint(x: 120, y: 390)))
    }

    @Test func fitsTheWholeCircleOfACircleWithAFlatSide() throws {
        let circle = Circle(center: CGPoint(x: 0, y: 0), radius: 10)
        // A chord across the top: its ends are on the circle, the arcs below.
        let fitted = try #require(Circle.through(points(on: circle, angles: [0.5, 2.64, 3.5, 4.7, 5.9])))
        #expect(fitted.isSame(as: circle, tolerance: 0.01))
    }

    @Test func findsNoCircleThroughPointsOffOne() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10),
                      CGPoint(x: 5, y: 0)]
        #expect(Circle.through(square) == nil)
        #expect(Circle.through([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]) == nil)
        #expect(Circle.through([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)]) == nil)
    }

    @Test func takesClipCirclesFromCurvesOnly() {
        var curved = Subpath()
        let circle = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 50, height: 50), transform: nil)
        circle.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: curved.add(line: points[0])
            case .addCurveToPoint: curved.add(curveTo: points[2], controls: [points[0], points[1]])
            default: break
            }
        }
        #expect(curved.circle()?.isSame(as: Circle(center: CGPoint(x: 25, y: 25), radius: 25), tolerance: 0.1) == true)
        var straight = Subpath()
        [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 50)].forEach { straight.add(line: $0) }
        #expect(straight.circle() == nil)
    }
}

@Suite struct TextScanningTests {
    let toUnicode = """
        /CIDInit /ProcSet findresource begin
        begincmap
        1 begincodespacerange <00> <FF> endcodespacerange
        1 beginbfchar
        <1F> <002D>
        endbfchar
        2 beginbfrange
        <41> <43> <0061>
        <44> <45> [<0058> <0059>]
        endbfrange
        endcmap
        """

    func scannedGlyphs(_ content: String) -> [TextGlyph] {
        let pdf = rawPDF(content: content, resources: "<< /Font << /F1 5 0 R /F2 7 0 R >> >>", extraObjects: [
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /ToUnicode 6 0 R >>",
            streamObject(toUnicode),
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
        ])
        return PageScanner.scan(pdf.page(at: 1)!).glyphs
    }

    @Test func decodesTextThroughTheFontsToUnicodeMap() {
        let glyphs = scannedGlyphs("BT /F1 12 Tf 10 20 Td (\\037AB) Tj [(C) 120 (DE)] TJ (Z) Tj ET")
        #expect(glyphs.map(\.text) == ["-ab", "cXY", "Z"])
    }

    @Test func readsFontsWithoutAMapAsTextStrings() {
        #expect(scannedGlyphs("BT /F2 12 Tf (Hello) Tj ET").map(\.text) == ["Hello"])
    }

    @Test func placesTextByItsMatricesAndTheTransform() {
        let glyphs = scannedGlyphs("""
            2 0 0 2 100 100 cm BT /F2 1 Tf 10 20 Td (A) Tj 5 -10 TD (B) ' 0 1 -1 0 30 40 Tm (C) Tj ET \
            BT (D) Tj ET
            """)
        #expect(glyphs.map(\.text) == ["A", "B", "C", "D"])
        #expect(glyphs.map(\.origin) == [CGPoint(x: 120, y: 140), CGPoint(x: 130, y: 120),
                                         CGPoint(x: 160, y: 180), CGPoint(x: 100, y: 100)])
    }
}
