import CoreGraphics
import Testing
@testable import PawnShopCore

@Suite struct NamedPaperTests {
    @Test func letterIsTheSheetsDefaultPaper() {
        #expect(NamedPaper.letter.setup == .letter)
        #expect(PaperSetup.letter.named == .letter)
    }

    @Test func everyPaperHasAQuarterInchMargin() {
        for paper in NamedPaper.allCases {
            let setup = paper.setup
            #expect(setup.imageableRect.minX == 18 && setup.imageableRect.minY == 18)
            #expect(setup.paperSize.width - setup.imageableRect.maxX == 18)
            #expect(paper.size.height > paper.size.width)
            #expect(!paper.title.isEmpty && paper.id == paper.rawValue)
        }
    }

    @Test func namesAPaperByItsSizeWhateverItsMargin() {
        let a4FromPageSetup = PaperSetup(paperSize: CGSize(width: 595, height: 842),
                                         imageableRect: CGRect(x: 12, y: 12, width: 571, height: 818))
        #expect(a4FromPageSetup.named == .a4)
        #expect(PaperSetup(paperSize: CGSize(width: 300, height: 400), imageableRect: .zero).named == nil)
    }

    @Test func choosingANamedPaperSetsItsSizeAndMargin() {
        var paper = PaperSetup.letter
        paper.named = .a3
        #expect(paper == NamedPaper.a3.setup)
        paper.named = nil
        #expect(paper == NamedPaper.a3.setup)
    }
}
