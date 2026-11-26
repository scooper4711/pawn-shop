#if os(macOS)
import AppKit
import Foundation
import Testing
@testable import PawnShopCore

/// A page setup that differs from the system's default in paper and orientation.
private func makeLandscapeA3() -> NSPrintInfo {
    let setup = NSPrintInfo()
    setup.paperSize = CGSize(width: 841.89, height: 1190.55)
    setup.orientation = .landscape
    return setup
}

@Suite struct SheetPageSetupTests {
    @Test func aConfirmedPageSetupBecomesTheSheetsPaper() throws {
        let setup = makeLandscapeA3()
        let paper = try #require(PaperSetup(pageSetup: setup))

        #expect(paper.paperSize == setup.paperSize)
        #expect(paper.imageableRect == setup.imageablePageBounds)
        #expect(paper.pageSetup != nil)
    }

    @Test func pageSetupStartsFromTheSetupKeptWithThePaper() throws {
        let paper = try #require(PaperSetup(pageSetup: makeLandscapeA3()))

        let restored = paper.printInfo()
        #expect(restored.orientation == .landscape)
        #expect(restored.paperSize == paper.paperSize)
    }

    @Test func aPaperWithoutAPageSetupStartsAtItsSize() {
        let info = NamedPaper.a4.setup.printInfo()
        #expect(abs(info.paperSize.width - NamedPaper.a4.size.width) < 1)
        #expect(abs(info.paperSize.height - NamedPaper.a4.size.height) < 1)
    }

    @Test func aPageSetupWithoutAPrintablePageGivesNoPaper() {
        let setup = NSPrintInfo()
        setup.paperSize = .zero
        #expect(PaperSetup(pageSetup: setup) == nil)
    }

    @Test func choosingANamedPaperDropsTheMacsPageSetup() throws {
        var paper = try #require(PaperSetup(pageSetup: makeLandscapeA3()))
        paper.named = .letter
        #expect(paper.pageSetup == nil)
        #expect(paper == NamedPaper.letter.setup)
    }

    @Test func thePageSetupIsSavedWithTheSheet() throws {
        let paper = try #require(PaperSetup(pageSetup: makeLandscapeA3()))
        let data = try JSONEncoder().encode(paper)

        let decoded = try JSONDecoder().decode(PaperSetup.self, from: data)
        #expect(decoded == paper)
        #expect(decoded.printInfo().orientation == .landscape)
    }

    @Test func aSheetSavedWithoutAPageSetupStillOpens() throws {
        let data = try JSONEncoder().encode(PaperSetup.letter)
        let json = try #require(String(bytes: data, encoding: .utf8))
        #expect(json.contains("pageSetup") == false)

        let decoded = try JSONDecoder().decode(PaperSetup.self, from: data)
        #expect(decoded == .letter)
    }
}

@Suite struct SheetPaperDefaultTests {
    private let suiteName = "SheetPaperDefaultTests.\(UUID().uuidString)"

    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suiteName))
    }

    @Test func newSheetsKeepTheirPaperUntilAPageSetupIsConfirmed() throws {
        #expect(SheetPaperDefault(defaults: try makeDefaults()).startingPaper == nil)
    }

    @Test func newSheetsStartOnTheLastConfirmedPaper() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        SheetPaperDefault(defaults: defaults).confirm(makeLandscapeA3())

        let paper = try #require(SheetPaperDefault(defaults: defaults).startingPaper)
        #expect(paper.paperSize == makeLandscapeA3().paperSize)
        #expect(paper.printInfo().orientation == .landscape)
    }
}
#endif
