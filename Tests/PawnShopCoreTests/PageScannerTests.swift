import CoreGraphics
import Testing
@testable import PawnShopCore

@Suite struct PawnSizeTests {
    @Test(arguments: PawnSize.allCases)
    func classifiesEachTableSize(size: PawnSize) {
        #expect(PawnSize.classify(size.outlineSize) == size)
    }

    @Test func toleratesSmallDifferences() {
        #expect(PawnSize.classify(CGSize(width: 80.9, height: 137.7)) == .medium)
        #expect(PawnSize.classify(CGSize(width: 84, height: 141)) == .medium)
    }

    @Test func rejectsOtherSizes() {
        #expect(PawnSize.classify(CGSize(width: 81, height: 100)) == nil)
        #expect(PawnSize.classify(CGSize(width: 138, height: 81)) == nil)
    }

    @Test func ordersSmallestFirst() {
        #expect(PawnSize.allCases.sorted() == PawnSize.allCases)
        #expect(PawnSize.huge > PawnSize.large)
        #expect(PawnSize.medium.displayName == "Medium")
    }
}

@Suite struct OutlineTests {
    @Test(arguments: [(Edge.top, 0), (.right, 90), (.bottom, 180), (.left, 270)])
    func turnsTheHeadUpright(head: Edge, degrees: Int) {
        let outline = Outline(rect: CGRect(x: 0, y: 0, width: 10, height: 20), headEdge: head)
        #expect(outline.uprightRotation == degrees)
    }

    @Test func swapsTheSizeOfSidewaysOutlines() {
        let sideways = Outline(rect: CGRect(x: 0, y: 0, width: 138, height: 81), headEdge: .left)
        #expect(sideways.uprightSize == CGSize(width: 81, height: 138))
        #expect(sideways.size == .medium)
    }
}

@Suite struct PageScannerTests {
    @Test func findsOutlinesWithTheirHeadEdge() throws {
        let medium = CGRect(x: 20, y: 600, width: 81, height: 138)
        let large = CGRect(x: 200, y: 600, width: 180, height: 138)
        let data = makePDF(pages: [{ context in
            strokeOutline(context, medium)
            strokeOutline(context, large, head: .right)
        }])
        let outlines = PageScanner.outlines(on: try #require(document(data).page(at: 1)))
        #expect(outlines.count == 2)
        #expect(outlines[0].headEdge == .top)
        #expect(outlines[0].size == .medium)
        #expect(abs(outlines[0].rect.minX - medium.minX) < 0.5)
        #expect(outlines[1].headEdge == .right)
        #expect(outlines[1].size == .large)
    }

    @Test(arguments: [Edge.left, .bottom])
    func findsOtherOrientations(head: Edge) throws {
        let rect = head == .left ? CGRect(x: 50, y: 50, width: 138, height: 81)
                                 : CGRect(x: 50, y: 50, width: 81, height: 138)
        let data = makePDF(pages: [{ context in strokeOutline(context, rect, head: head) }])
        let outlines = PageScanner.outlines(on: try #require(document(data).page(at: 1)))
        #expect(outlines.map(\.headEdge) == [head])
    }

    @Test func ignoresRectanglesAndFilledShapes() throws {
        let data = makePDF(pages: [{ context in
            context.stroke(CGRect(x: 10, y: 10, width: 81, height: 138))
            context.addPath(outlinePath(CGRect(x: 200, y: 10, width: 81, height: 138)))
            context.fillPath()
        }])
        #expect(PageScanner.outlines(on: try #require(document(data).page(at: 1))).isEmpty)
    }

    @Test func findsOutlinesInsideFormXObjects() throws {
        let small = CGRect(x: 20, y: 30, width: 81, height: 60)
        let inner = makePDF(pages: [{ context in strokeOutline(context, small, head: .left) }])
        let outer = document(wrappedInForms(document(inner)))
        let outlines = PageScanner.outlines(on: try #require(outer.page(at: 1)))
        #expect(outlines.count == 1)
        #expect(outlines.first?.size == .small)
        #expect(abs((outlines.first?.rect.minY ?? 0) - 30) < 0.5)
    }

    @Test func readsShortCurvesUnderATransform() throws {
        // The shape Paizo's InDesign files use: `v` curves, drawn from the bottom right after a `cm`.
        let content = """
        q 0.3 w q 1 0 0 1 98.05 637.1 cm
        0 0 m 0 111.99 l 0 137.67 -29.31 137.67 v -51.6 137.67 l -80.9 137.67 -80.9 111.99 v -80.9 0 l 0 0 l h S
        Q Q
        q 1 0 0 1 300 100 cm 0 0 m 0 112 l 0 137.67 29.3 137.67 y 51.6 137.67 l 80.9 137.67 80.9 112 y 80.9 0 l h S Q
        """
        let outlines = PageScanner.outlines(on: try #require(rawPDF(content: content).page(at: 1)))
        #expect(outlines.count == 2)
        #expect(outlines.allSatisfy { $0.headEdge == .top && $0.size == .medium })
        #expect(abs((outlines.first?.rect.minX ?? 0) - 17.15) < 0.1)
        #expect(abs((outlines.last?.rect.minX ?? 0) - 300) < 0.1)
    }

    @Test func clearsPathsEndedWithoutStroking() throws {
        let content = """
        0 0 m 0 112 l 0 137.67 29.3 137.67 y 51.6 137.67 l 80.9 137.67 80.9 112 y 80.9 0 l h n
        10 10 50 50 re S
        """
        #expect(PageScanner.outlines(on: try #require(rawPDF(content: content).page(at: 1))).isEmpty)
    }
}
