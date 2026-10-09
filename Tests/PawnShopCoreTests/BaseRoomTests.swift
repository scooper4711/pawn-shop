import CoreGraphics
import Foundation
import Testing
@testable import PawnShopCore

@Suite struct BaseRoomTests {
    @Test func leavesTheDepthOfThePackagedBasesSlotByDefault() throws {
        let scad = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("pawn-bases/pawn_base.scad")
        let source = try String(contentsOf: scad, encoding: .utf8)
        let line = try #require(source.split(separator: "\n").first { $0.hasPrefix("slot_depth = ") })
        let depth = try #require(Double(line.dropFirst("slot_depth = ".count).prefix { $0 != ";" }))
        #expect(abs(SheetSettings.defaultBaseRoom.millimeters - depth) < 0.001)
    }

    @Test func leavesRoomOnlyWhenAsked() {
        var settings = SheetSettings()
        #expect(!settings.leavesRoomForBase && settings.footRoom == 0)
        settings.leavesRoomForBase = true
        #expect(abs(settings.footRoom - 6 / 25.4 * 72) < 0.001)
        settings.baseRoom = -3
        #expect(settings.footRoom == 0)
    }

    @Test func makesStripsTallerByTheRoomUnderBothFeet() {
        let medium = PawnSize.medium.outlineSize
        #expect(LayoutItem.stripSize(forPawn: medium, footRoom: 10) == CGSize(width: 81, height: 296))
        #expect(LayoutItem.stripSize(forPawn: medium, footRoom: -5) == LayoutItem.stripSize(forPawn: medium))
    }

    @Test func readsSheetsSavedBeforeRoomForABase() throws {
        var settings = SheetSettings(cutStyle: .gaps(9), showsFoldLine: false)
        settings.leavesRoomForBase = true
        settings.baseRoom = .millimeters(4)
        let encoded = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(SheetSettings.self, from: encoded) == settings)
        var stored = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        stored["leavesRoomForBase"] = nil
        stored["baseRoom"] = nil
        let old = try JSONDecoder().decode(SheetSettings.self, from: JSONSerialization.data(withJSONObject: stored))
        #expect(!old.leavesRoomForBase && old.baseRoom == SheetSettings.defaultBaseRoom && old.cutStyle == .gaps(9))
    }

    @Test func laysOutTallerStripsForASheetLeavingRoom() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        var sheet = PawnSheet()
        sheet.add(UUID())
        sheet.settings.leavesRoomForBase = true
        let exporter = SheetExporter(sheet: sheet, library: library, renderer: PawnRenderer(library: library))
        let expected = LayoutItem.stripSize(forPawn: PawnSize.medium.outlineSize, footRoom: sheet.settings.footRoom)
        #expect(exporter.layoutItems().first?.stripSize == expected)
    }

    @Test func drawsBothFacesAboveBlankRoomAtTheirFeet() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        writePNG(headRedImage(), to: library.customFolder.appendingPathComponent("hero.png"))
        let hero = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png", showsName: false)))
        var settings = SheetSettings(showsFoldLine: false)
        settings.leavesRoomForBase = true
        settings.baseRoom = 20
        let canvas = Canvas(size: CGSize(width: 81, height: 316))
        let placed = PlacedStrip(entryID: UUID(), copy: 0, rect: CGRect(x: 0, y: 0, width: 81, height: 316),
                                 sideways: false)
        PawnRenderer(library: library).drawStrip(hero, in: placed, settings: settings, context: canvas.context)
        // Blank room at both ends, then each face's foot (blue) and head (red) meeting at the fold.
        #expect(canvas.color(atX: 40, y: 10) == "other" && canvas.color(atX: 40, y: 306) == "other")
        #expect(canvas.color(atX: 40, y: 30) == "blue" && canvas.color(atX: 40, y: 286) == "blue")
        #expect(canvas.color(atX: 40, y: 150) == "red" && canvas.color(atX: 40, y: 166) == "red")
    }
}
