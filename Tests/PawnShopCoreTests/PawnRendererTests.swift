import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PawnShopCore

/// A picture whose top half is red and bottom half blue, to tell which way up it was drawn.
func headRedImage(width: Int = 40, height: Int = 80) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

/// An RGBA bitmap to draw into and read pixels back from, with y measured from the bottom.
struct Canvas {
    let context: CGContext
    let size: CGSize

    init(size: CGSize) {
        self.size = size
        context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                            bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    /// "red", "blue", or "other" for the pixel at (x, y).
    func color(atX column: Int, y row: Int) -> String {
        let pixels = context.data!.bindMemory(to: UInt8.self, capacity: Int(size.width * size.height) * 4)
        let offset = ((Int(size.height) - 1 - row) * Int(size.width) + column) * 4
        let (red, blue) = (pixels[offset], pixels[offset + 2])
        if red > 200 && blue < 60 { return "red" }
        if blue > 200 && red < 60 { return "blue" }
        return "other"
    }
}

@Suite struct PawnRendererTests {
    let library: PawnLibrary
    let renderer: PawnRenderer
    let custom: Pawn

    init() throws {
        library = try PawnLibrary(folder: temporaryFolder())
        writePNG(headRedImage(), to: library.customFolder.appendingPathComponent("hero.png"))
        custom = Pawn(name: "Hero", size: .medium, art: .custom(CustomArt(imageFile: "hero.png", showsName: false)))
        try library.add(custom)
        renderer = PawnRenderer(library: library)
    }

    @Test func foldsTheBackAboveTheFrontHeadToHead() {
        let canvas = Canvas(size: CGSize(width: 81, height: 276))
        let placed = PlacedStrip(entryID: UUID(), copy: 0, rect: CGRect(x: 0, y: 0, width: 81, height: 276),
                                 sideways: false)
        renderer.drawStrip(custom, in: placed, settings: SheetSettings(), context: canvas.context)
        #expect(canvas.color(atX: 40, y: 20) == "blue")
        #expect(canvas.color(atX: 40, y: 125) == "red")
        #expect(canvas.color(atX: 40, y: 150) == "red")
        #expect(canvas.color(atX: 40, y: 256) == "blue")
    }

    @Test func laysSidewaysStripsWithTheFootOnTheLeft() {
        let canvas = Canvas(size: CGSize(width: 276, height: 81))
        let placed = PlacedStrip(entryID: UUID(), copy: 0, rect: CGRect(x: 0, y: 0, width: 276, height: 81),
                                 sideways: true)
        renderer.drawStrip(custom, in: placed, settings: SheetSettings(showsFoldLine: false), context: canvas.context)
        #expect(canvas.color(atX: 20, y: 40) == "blue")
        #expect(canvas.color(atX: 125, y: 40) == "red")
        #expect(canvas.color(atX: 256, y: 40) == "blue")
    }

    @Test func drawsMissingPawnsAsPlaceholders() {
        let canvas = Canvas(size: CGSize(width: 81, height: 276))
        let placed = PlacedStrip(entryID: UUID(), copy: 0, rect: CGRect(x: 0, y: 0, width: 81, height: 276),
                                 sideways: false)
        renderer.drawStrip(nil, in: placed, settings: SheetSettings(), context: canvas.context)
        #expect(canvas.color(atX: 40, y: 60) == "other")
    }

    @Test func makesThumbnailsOfPDFPawns() throws {
        let folder = temporaryFolder()
        let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: artImage(), name: "GOBLIN")
        try library.importPDF(at: writePawnPDF([goblin], named: "Goblins.pdf", in: folder))
        let pawn = try #require(library.pawns.first { $0.name == "Goblin" })
        let thumbnail = try #require(renderer.thumbnail(of: pawn, side: .back, height: 138))
        #expect(thumbnail.width == 81)
        #expect(abs(renderer.uprightSize(of: pawn).width - 81) < 1)
        let face = PawnFace(pageIndex: 0, rect: CGRect(x: 0, y: 0, width: 81, height: 138), rotation: 0)
        let lost = Pawn(name: "Lost", size: .medium, art: .pdf(sourceID: "missing", front: face, back: face))
        #expect(renderer.thumbnail(of: lost, height: 50) != nil)
        #expect(renderer.thumbnail(of: custom, height: 0) == nil)
    }

    @Test func growsTheNameBandForTwoLines() throws {
        var named = custom
        named.name = "Nodocite Experimenter"
        named.art = .custom(CustomArt(imageFile: "hero.png", showsName: true))
        let canvas = Canvas(size: CGSize(width: 81, height: 138))
        renderer.drawFace(of: named, side: .front, in: CGRect(x: 0, y: 0, width: 81, height: 138),
                          context: canvas.context)
        // One line takes 13% of the height (18 pt); two lines take more.
        #expect(canvas.color(atX: 2, y: 20) == "other")
        #expect(canvas.color(atX: 2, y: 40) == "blue")
    }

    @Test func coversTheOutlineWithCustomArt() {
        let rect = CGRect(x: 0, y: 0, width: 50, height: 50)
        let wide = CGSize(width: 100, height: 50), center = CGPoint(x: 0.5, y: 0.5)
        #expect(PawnRenderer.artRect(for: wide, in: rect, focus: center, scaling: .fill)
                == CGRect(x: -25, y: 0, width: 100, height: 50))
        #expect(PawnRenderer.artRect(for: wide, in: rect, focus: CGPoint(x: 2, y: 0), scaling: .fill).minX == -50)
        #expect(PawnRenderer.artRect(for: .zero, in: rect, focus: .zero, scaling: .fill) == rect)
    }

    @Test func fitsTheWholePictureWhenAsked() {
        let rect = CGRect(x: 0, y: 0, width: 50, height: 50), wide = CGSize(width: 100, height: 50)
        #expect(PawnRenderer.artRect(for: wide, in: rect, focus: CGPoint(x: 0.5, y: 0.5), scaling: .fit)
                == CGRect(x: 0, y: 12.5, width: 50, height: 25))
        #expect(PawnRenderer.artRect(for: wide, in: rect, focus: CGPoint(x: 0.5, y: 1), scaling: .fit).maxY == 50)
        let face = CGRect(x: 0, y: 0, width: 81, height: 138)
        let fitted = CustomArt(imageFile: "x", scaling: .fit)
        let area = PawnRenderer.artArea(for: fitted, named: "Goblin", in: face)
        #expect(area.minY == PawnRenderer.nameBandHeight(for: "Goblin", in: face) && area.maxY == 138)
        #expect(PawnRenderer.artArea(for: CustomArt(imageFile: "x"), named: "Goblin", in: face) == face)
        #expect(PawnRenderer.nameBandHeight(for: "Nodocite Experimenter", in: face)
                > PawnRenderer.nameBandHeight(for: "Goblin", in: face))
        #expect(ArtScaling.fit.displayName == "Fit Whole Picture" && ArtScaling.fill.displayName == "Fill Pawn")
    }

    @Test func leavesWhiteBesideAFittedPicture() throws {
        var fitted = custom
        fitted.art = .custom(CustomArt(imageFile: "hero.png", showsName: false, scaling: .fit))
        let canvas = Canvas(size: CGSize(width: 81, height: 138))
        renderer.drawFace(of: fitted, side: .front, in: CGRect(x: 0, y: 0, width: 81, height: 138),
                          context: canvas.context)
        // The 1:2 picture is narrower than the pawn: white at the sides, red in the middle.
        #expect(canvas.color(atX: 1, y: 100) == "other")
        #expect(canvas.color(atX: 40, y: 100) == "red")
        let filled = Canvas(size: CGSize(width: 81, height: 138))
        renderer.drawFace(of: custom, side: .front, in: CGRect(x: 0, y: 0, width: 81, height: 138),
                          context: filled.context)
        #expect(filled.color(atX: 1, y: 100) == "red")
    }

    @Test func printsTheNameOnCustomPawns() throws {
        var named = custom
        named.art = .custom(CustomArt(imageFile: "hero.png", showsName: true))
        let canvas = Canvas(size: CGSize(width: 81, height: 138))
        renderer.drawFace(of: named, side: .front, in: CGRect(x: 0, y: 0, width: 81, height: 138),
                          context: canvas.context)
        #expect(canvas.color(atX: 2, y: 4) == "other")
        #expect(canvas.color(atX: 2, y: 40) == "blue")
    }
}

@Suite struct SheetExporterTests {
    @Test func exportsOnePDFPagePerLayoutPage() throws {
        let library = try PawnLibrary(folder: temporaryFolder())
        writePNG(headRedImage(), to: library.customFolder.appendingPathComponent("hero.png"))
        let hero = Pawn(name: "Hero", size: .huge, art: .custom(CustomArt(imageFile: "hero.png")))
        try library.add(hero)
        var sheet = PawnSheet()
        sheet.add(hero.id, copies: 4)
        sheet.add(UUID())
        let exporter = SheetExporter(sheet: sheet, library: library, renderer: PawnRenderer(library: library))
        #expect(exporter.layoutItems().last?.stripSize == LayoutItem.stripSize(forPawn: PawnSize.medium.outlineSize))
        let pdf = document(exporter.pdfData())
        #expect(pdf.numberOfPages == exporter.layout().pages.count)
        #expect(pdf.page(at: 1)?.getBoxRect(.mediaBox).size == PaperSetup.letter.paperSize)
    }
}
