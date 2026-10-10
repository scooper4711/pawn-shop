import CoreGraphics
import Foundation
import Testing
import ArtExtraction
@testable import PawnShopCore

@Suite struct NameLayoutTests {
    /// The width a medium pawn's name may use, and its full type size.
    let width = PawnSize.medium.outlineSize.width * 0.92
    let size = PawnSize.medium.outlineSize.height * 0.13 * 0.6

    @Test func keepsShortNamesOnOneLineAtFullSize() {
        #expect(NameLayout.fit("GOBLIN", width: width, fontSize: size) == NameLayout(lines: ["GOBLIN"], fontSize: size))
    }

    @Test func wrapsLongNamesOntoTwoLinesBeforeShrinking() {
        let layout = NameLayout.fit("NODOCITE EXPERIMENTER", width: width, fontSize: size)
        #expect(layout.lines == ["NODOCITE", "EXPERIMENTER"])
        #expect(layout.fontSize > size * 0.8)
        #expect(NameLayout.fits(layout.lines, width: width, size: layout.fontSize))
        #expect(!NameLayout.fits(["NODOCITE EXPERIMENTER"], width: width, size: layout.fontSize))
    }

    @Test func shrinksWhenTwoLinesAreNotEnough() {
        let layout = NameLayout.fit("HONORARY TRIBUNE ONARA PISCUM OF THE SENATE", width: width, fontSize: size)
        #expect(layout.lines.count == 2 && layout.fontSize < size)
        #expect(NameLayout.fits(layout.lines, width: width, size: layout.fontSize))
    }

    @Test func shrinksASingleLongWord() {
        let layout = NameLayout.fit("SUPERCALIFRAGILISTICEXPIALIDOCIOUS", width: width, fontSize: size)
        #expect(layout.lines.count == 1 && layout.fontSize < size)
    }

    @Test func stopsAtTheSmallestSize() {
        let layout = NameLayout.fit("A VERY LONG NAME INDEED", width: 5, fontSize: size)
        #expect(layout.fontSize == NameLayout.smallestSize && layout.lines.count == 2)
        #expect(NameLayout.fit("  ", width: width, fontSize: size).lines.isEmpty)
    }

    @Test func prefersEvenSplits() {
        #expect(NameLayout.twoLineSplits(["AB", "CDEF", "GH"]).first == ["AB CDEF", "GH"]
                || NameLayout.twoLineSplits(["AB", "CDEF", "GH"]).first == ["AB", "CDEF GH"])
        #expect(NameLayout.twoLineSplits(["ONE"]).isEmpty)
    }
}
