import CoreGraphics
import CoreText
import Foundation
import Testing
import ArtExtraction
import ArtExtractionTestSupport
@testable import PawnShopCore

/// Drawing item cards.
@Suite struct ItemCardTests {
    let library: PawnLibrary
    let renderer: PawnRenderer

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
        renderer = PawnRenderer(library: library)
        renderer.generatedFolder = nil
    }

    @Test func drawsTheItemsArtFaintlyBehindTheText() throws {
        writePNG(solidImage(red: 1, green: 0, blue: 0), to: library.folders.items.appendingPathComponent("art.png"))
        var item = catalogItem("Potion", level: 1)
        item.description = ""
        let plain = try #require(renderer.cardImage(ItemCardContent(item: item, artwork: nil), height: 352))
        let withArt = try #require(renderer.cardImage(ItemCardContent(item: item, artwork: art("Potion")),
                                                      height: 352))
        let center = (x: plain.width / 2, y: plain.height / 2)
        #expect(pixel(of: plain, x: center.x, y: center.y).prefix(3) == [255, 255, 255])
        let faint = pixel(of: withArt, x: center.x, y: center.y)
        #expect(faint[0] > 240 && faint[1] > 150 && faint[1] < 220)
        renderer.itemArtOpacity = 0
        let none = try #require(renderer.cardImage(ItemCardContent(item: item, artwork: art("Potion")), height: 352))
        #expect(pixel(of: none, x: center.x, y: center.y).prefix(3) == [255, 255, 255])
        renderer.itemArtOpacity = 1
        let solid = try #require(renderer.cardImage(ItemCardContent(item: item, artwork: art("Potion")), height: 352))
        #expect(pixel(of: solid, x: center.x, y: center.y).prefix(3) == [255, 0, 0])
    }

    @Test func drawsWithoutArtWhenTheDeckIsGone() throws {
        let card = ItemCardContent(item: catalogItem("Potion", level: 1), artwork: ItemArtwork(
            name: "Potion", sourceID: "gone", picture: .figure(face: PawnFace(pageIndex: 0, rect: .zero, rotation: 0),
                                                               imageIndex: 0),
            fingerprint: ArtFingerprint(imageDigests: [])))
        #expect(renderer.cardImage(card, height: 100) != nil)
        #expect(renderer.cardImage(card, height: 0) == nil)
    }

    @Test func drawsEachGamesPiecesFromTheGeneratedFolder() throws {
        let generated = try fakeGenerated()
        renderer.generatedFolder = generated
        let pathfinder = try #require(renderer.cardImage(ItemCardContent(item: catalogItem("Potion", level: 1),
                                                                         artwork: nil), height: 352))
        // The parchment piece is green; a plain card is white.
        #expect(pixel(of: pathfinder, x: pathfinder.width / 2, y: pathfinder.height - 60)[1] > 200)
        #expect(pixel(of: pathfinder, x: pathfinder.width / 2, y: pathfinder.height - 60)[0] < 50)
        let starfinder = catalogItem("Serum", level: 1, game: .starfinder)
        let image = try #require(renderer.cardImage(ItemCardContent(item: starfinder, artwork: nil), height: 352))
        #expect(pixel(of: image, x: image.width / 2, y: image.height - 60)[1] > 200)
        renderer.generatedFolder = nil
        let plain = try #require(renderer.cardImage(ItemCardContent(item: starfinder, artwork: nil), height: 352))
        #expect(pixel(of: plain, x: plain.width / 2, y: plain.height - 60).prefix(3) == [255, 255, 255])
    }

    @Test func setsActionGlyphsInTheActionFontWhenThereIsOne() throws {
        let markup = "**Activate** ◆◆ Interact\n---\nYou drink it ⤾."
        let plain = ItemCardText(markup: markup, ink: CGColor(gray: 0, alpha: 1)).attributed(size: 8)
        #expect(plain.string == "Activate ◆◆ Interact\n\u{00A0}\nYou drink it ⤾.")
        let font = CTFontDescriptorCreateWithNameAndSize("Courier" as CFString, 8)
        let iconic = ItemCardText(markup: markup, ink: CGColor(gray: 0, alpha: 1), actionFont: font)
            .attributed(size: 8)
        #expect(iconic.string == "Activate \u{E901} Interact\n\u{00A0}\nYou drink it \u{E904}.")
        let glyph = iconic.attribute(.init(kCTFontAttributeName as String), at: 9, effectiveRange: nil)
        // The attribute is always a font.
        #expect(CTFontCopyFamilyName(glyph as! CTFont) as String == "Courier") // swiftlint:disable:this force_cast
        #expect(CTFontGetSize(glyph as! CTFont) == 8 * ItemCardText.actionScale) // swiftlint:disable:this force_cast
        let shift = iconic.attribute(.init(kCTBaselineOffsetAttributeName as String), at: 9, effectiveRange: nil)
        #expect(shift as? CGFloat == 8 * ItemCardText.actionBaselineShift)
    }

    @Test func shrinksLongTextAndThenCutsItShort() {
        let text = ItemCardText(markup: String(repeating: "Words fill the card. ", count: 200),
                                ink: CGColor(gray: 0, alpha: 1))
        let rect = CGRect(x: 0, y: 0, width: 150, height: 120)
        let frame = text.fittedFrame(in: rect)
        let visible = CTFrameGetVisibleStringRange(frame)
        let string = CTFrameGetStringRange(frame)
        #expect(visible.length == string.length)
        #expect(string.length < CFAttributedStringGetLength(text.attributed(size: ItemCardText.smallestSize)))
        let short = ItemCardText(markup: "Short.", ink: CGColor(gray: 0, alpha: 1)).fittedFrame(in: rect)
        let lines = CTFrameGetLines(short) as? [CTLine] ?? []
        let run = (CTLineGetGlyphRuns(lines[0]) as? [CTRun] ?? [])[0]
        let attributes = CTRunGetAttributes(run) as NSDictionary
        // A run always has a font.
        let font = attributes[kCTFontAttributeName] as! CTFont // swiftlint:disable:this force_cast
        #expect(CTFontGetSize(font) == ItemCardText.largestSize)
    }

    @Test func putsTwoStatsToARowUnlessOneIsTooWide() {
        let stats = [ItemStat("Level", "1"), ItemStat("Price", "4 gp"), ItemStat("Usage", "very long"),
                     ItemStat("Bulk", "L")]
        let rows = ItemCardPainter.statRows(stats, width: 100) { $0.label == "Usage" ? 80 : 20 }
        #expect(rows.map { $0.map(\.label) } == [["Level", "Price"], ["Usage"], ["Bulk"]])
    }

    @Test func fitsTheNameOnOneLineOrTwo() {
        #expect(ItemCardPainter.fittedName("POTION", width: 150).lines == ["POTION"])
        let long = ItemCardPainter.fittedName("ELIXIR OF LIFE (MINOR)", width: 60)
        #expect(long.lines.count == 2 && long.size >= 6)
    }

    @Test func colorsRarityChipsAsTheBooksDo() {
        #expect(ItemCardStyle.rarityFill("Rare") != nil && ItemCardStyle.rarityFill("Uncommon") != nil)
        #expect(ItemCardStyle.rarityFill("Unique") != nil && ItemCardStyle.rarityFill("Magical") == nil)
    }

    /// A `Generated` folder whose pieces are all green squares.
    private func fakeGenerated() throws -> URL {
        let folder = temporaryFolder().appendingPathComponent("CardArt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in ["parchment", "front-frame", "name-ribbon", "panel", "corner-top-left", "corner-top-right",
                     "corner-bottom-left", "corner-bottom-right", "name-bar"] {
            writePNG(solidImage(red: 0, green: 1, blue: 0, size: 120), to: folder.appendingPathComponent(name + ".png"))
        }
        return folder.deletingLastPathComponent()
    }
}

func solidImage(red: CGFloat, green: CGFloat, blue: CGFloat, size: Int = 60) -> CGImage {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    return context.makeImage()!
}

@Suite struct ItemCardLayoutTests {
    @Test func placesARibbonsFaceOverTheTitle() {
        let title = CGRect(x: 13, y: 200, width: 140, height: 20)
        let face = CGRect(x: 0.25, y: 0, width: 0.5, height: 0.5)
        let band = ItemCardPainter.bandRect(placingFace: face, over: title)
        #expect(band == CGRect(x: -57, y: 180, width: 280, height: 40))
    }
}
