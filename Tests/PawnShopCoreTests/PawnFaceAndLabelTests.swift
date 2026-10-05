import CoreGraphics
import Testing
@testable import PawnShopCore

@Suite struct PawnFaceTests {
    let destination = CGRect(x: 100, y: 200, width: 30, height: 60)

    @Test func fillsTheDestinationUpright() {
        let face = PawnFace(pageIndex: 0, rect: CGRect(x: 10, y: 20, width: 30, height: 60), rotation: 0)
        let transform = face.transform(into: destination)
        #expect(close(CGPoint(x: 10, y: 20).applying(transform), CGPoint(x: 100, y: 200)))
        #expect(close(CGPoint(x: 40, y: 80).applying(transform), CGPoint(x: 130, y: 260)))
    }

    @Test func turnsASidewaysHeadToTheTop() {
        // Head on the right: its middle must land at the top middle of the destination.
        let face = PawnFace(pageIndex: 0, rect: CGRect(x: 0, y: 0, width: 60, height: 30), rotation: 90)
        #expect(face.uprightSize == CGSize(width: 30, height: 60))
        #expect(close(CGPoint(x: 60, y: 15).applying(face.transform(into: destination)), CGPoint(x: 115, y: 260)))
    }

    @Test func flipsMirroredFacesLeftToRight() {
        let face = PawnFace(pageIndex: 0, rect: CGRect(x: 10, y: 20, width: 30, height: 60), rotation: 0)
        let mirrored = face.mirroredCopy()
        #expect(mirrored.mirrored && !mirrored.mirroredCopy().mirrored)
        #expect(close(CGPoint(x: 10, y: 50).applying(mirrored.transform(into: destination)), CGPoint(x: 130, y: 230)))
    }

    private func close(_ first: CGPoint, _ second: CGPoint) -> Bool {
        abs(first.x - second.x) < 0.001 && abs(first.y - second.y) < 0.001
    }
}

@Suite struct PawnLabelTests {
    @Test func takesTheLargestTextAsTheName() {
        let runs = [LabelRun(text: "B\n", fontSize: 4), LabelRun(text: "62\n", fontSize: 4.5),
                    LabelRun(text: "AEON, AXIOMITE ", fontSize: 8), LabelRun(text: "© 2019 PAIZO INC.", fontSize: 4)]
        #expect(PawnLabel.name(from: runs) == "Aeon, Axiomite")
    }

    @Test func joinsLinesAndRestoresCapitalization() {
        let runs = [LabelRun(text: "“MILKSOP” MORTON OF\nTHE SHARK-EATING ISLES", fontSize: 8)]
        #expect(PawnLabel.name(from: runs) == "“Milksop” Morton of the Shark-Eating Isles")
    }

    @Test func readsDoubledLabelsOnce() {
        #expect(PawnLabel.undoubled("ALGHOLLTHU, U ALGHOLLTHU, UGOTHOL GOTHOL") == "ALGHOLLTHU, UGOTHOL")
        #expect(PawnLabel.undoubled("ANGEL, BALISSE ANGEL, BALISSE") == "ANGEL, BALISSE")
        let doubled = [LabelRun(text: "ANGEL, BALISSE ANGEL, BALISSE", fontSize: 8)]
        #expect(PawnLabel.name(from: doubled) == "Angel, Balisse")
    }

    @Test func leavesOrdinaryNamesAlone() {
        #expect(PawnLabel.undoubled("MIMI MIMI") == "MIMI MIMI")
        #expect(PawnLabel.undoubled("GOBLIN WARRIOR") == "GOBLIN WARRIOR")
    }

    @Test func givesNoNameForEmptyLabels() {
        #expect(PawnLabel.name(from: []).isEmpty)
        #expect(PawnLabel.name(from: [LabelRun(text: "© 2019 PAIZO INC.", fontSize: 4)]).isEmpty)
    }
}
