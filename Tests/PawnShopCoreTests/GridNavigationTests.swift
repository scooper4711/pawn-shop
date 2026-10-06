import Testing
@testable import PawnShopCore

@Suite struct GridNavigationTests {
    /// Seven items three wide: rows 0 1 2 / 3 4 5 / 6.
    func step(_ move: GridMove, from index: Int) -> Int {
        GridNavigation.index(after: move, from: index, count: 7, columns: 3)
    }

    @Test func movesAcrossAndDownRows() {
        #expect(step(.right, from: 2) == 3 && step(.left, from: 3) == 2)
        #expect(step(.down, from: 1) == 4 && step(.up, from: 4) == 1)
    }

    @Test func staysPutAtTheEdges() {
        #expect(step(.left, from: 0) == 0 && step(.right, from: 6) == 6)
        #expect(step(.up, from: 2) == 2 && step(.down, from: 6) == 6)
    }

    @Test func movesDownOntoAShorterLastRow() {
        #expect(step(.down, from: 5) == 6)
    }

    @Test func handlesEmptyAndOutOfRangeGrids() {
        #expect(GridNavigation.index(after: .down, from: 3, count: 0, columns: 3) == 0)
        #expect(GridNavigation.index(after: .right, from: 9, count: 4, columns: 0) == 3)
    }

    @Test func countsTheColumnsThatFit() {
        #expect(GridNavigation.columns(fitting: 295, minimum: 92, spacing: 10) == 2)
        #expect(GridNavigation.columns(fitting: 296, minimum: 92, spacing: 10) == 3)
        #expect(GridNavigation.columns(fitting: 50, minimum: 92, spacing: 10) == 1)
        #expect(GridNavigation.columns(fitting: 50, minimum: 0, spacing: 0) == 1)
    }
}
