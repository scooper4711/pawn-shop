import CoreGraphics
import Foundation
import Testing
@testable import SheetPreviewFile

@Suite struct SheetPreviewsTests {
    @Test func readsThePicturesBesideTheSheetsKeys() throws {
        let page = try jpeg()
        let json = #"{"entries":[],"previewPages":["\#(page.base64EncodedString())"]}"#
        #expect(SheetPreviews(fileData: Data(json.utf8)).pages == [page])
    }

    @Test func aFileWithoutPicturesHasNone() {
        #expect(SheetPreviews(fileData: Data(#"{"entries":[]}"#.utf8)).pages.isEmpty)
    }

    @Test func unreadablePicturesCountAsNone() {
        #expect(SheetPreviews(fileData: Data(#"{"previewPages":["not base64!"]}"#.utf8)).pages.isEmpty)
        #expect(SheetPreviews(fileData: Data("not json".utf8)).pages.isEmpty)
    }

    @Test func keepsAtMostTheMaximumPages() {
        let pages = Array(repeating: Data([1]), count: SheetPreviews.maximumPages + 5)
        #expect(SheetPreviews(pages: pages).pages.count == SheetPreviews.maximumPages)
    }

    @Test func noPicturesWriteNoKey() throws {
        let json = try JSONEncoder().encode(SheetPreviews())
        #expect(String(bytes: json, encoding: .utf8) == "{}")
    }

    @Test func theFirstPageIsTheThumbnail() throws {
        let previews = SheetPreviews(pages: [try jpeg(width: 40), try jpeg(width: 20)])
        #expect(previews.firstPageImage?.width == 40)
    }

    @Test func thePDFHasAPagePerPicture() throws {
        let previews = SheetPreviews(pages: [try jpeg(), try jpeg()])
        let provider = try #require(CGDataProvider(data: previews.pdfData() as CFData))
        #expect(CGPDFDocument(provider)?.numberOfPages == 2)
    }

    @Test func noReadablePictureMakesNoPDF() {
        #expect(SheetPreviews(pages: [Data([1, 2, 3])]).pdfData().isEmpty)
        #expect(SheetPreviews(pages: [Data([1, 2, 3])]).firstPageImage == nil)
    }

    private func jpeg(width: Int = 30) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: 40))
        let data = SheetPreviews.jpegData(of: try #require(context.makeImage()))
        #expect(!data.isEmpty)
        return data
    }
}
