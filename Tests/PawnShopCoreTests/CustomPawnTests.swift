import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

@Suite struct CustomPawnTests {
    let library: PawnLibrary

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
    }

    @Test func savesTheArtAndAddsThePawn() throws {
        let pawn = try library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: "  Hero ", size: .large,
                                                           focus: CGPoint(x: 0.2, y: 0.8), showsName: false))
        #expect(pawn.name == "Hero" && pawn.size == .large && pawn.isCustom)
        guard case .custom(let art) = pawn.art else { Issue.record("not custom art"); return }
        #expect(art.focus == CGPoint(x: 0.2, y: 0.8) && !art.showsName)
        let saved = try PawnLibrary.image(at: library.customFolder.appendingPathComponent(art.imageFile))
        #expect(saved.width == 40 && saved.height == 80)
        #expect(library.pawn(id: pawn.id) == pawn)
    }

    @Test func keepsTheChosenScaling() throws {
        var new = NewCustomPawn(image: headRedImage(), name: "Nodocite")
        new.scaling = .fit
        let pawn = try library.addCustomPawn(new)
        guard case .custom(let art) = pawn.art else { Issue.record("not custom art"); return }
        #expect(art.scaling == .fit)
    }

    @Test func readsArtSavedBeforeScalingExisted() throws {
        let json = #"{"imageFile":"old.png","focus":[0.5,0.5],"showsName":true}"#
        #expect(try JSONDecoder().decode(CustomArt.self, from: Data(json.utf8)).scaling == .fill)
    }

    @Test func namesUnnamedArt() throws {
        #expect(try library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: " ")).name == "Custom Pawn")
    }

    @Test func rejectsFilesThatAreNotImages() throws {
        let url = temporaryFolder().appendingPathComponent("notes.png")
        try Data("not an image".utf8).write(to: url)
        #expect(throws: PawnLibraryError.unreadableFile("notes.png")) { try PawnLibrary.image(at: url) }
    }

    @Test func reportsArtThatCannotBeSaved() throws {
        try FileManager.default.removeItem(at: library.customFolder)
        #expect(throws: PawnLibraryError.self) {
            try library.addCustomPawn(NewCustomPawn(image: headRedImage(), name: "Lost"))
        }
    }
}
