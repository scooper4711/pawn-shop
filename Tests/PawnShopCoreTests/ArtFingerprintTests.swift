import CoreGraphics
import Testing
@testable import PawnShopCore

@Suite struct EmbeddedImageTests {
    @Test func recordsWhereImagesAreDrawnAndWhatTheyShow() throws {
        let data = makePDF(pages: [{ context in
            context.draw(artImage(), in: CGRect(x: 10, y: 20, width: 60, height: 90))
            context.draw(jpegImage(artImage(variant: 1)), in: CGRect(x: 100, y: 20, width: 60, height: 90))
        }])
        let images = PageScanner.scan(try #require(document(data).page(at: 1))).images
        #expect(images.count == 2)
        #expect(abs(images[0].rect.minX - 10) < 0.5 && abs(images[0].rect.height - 90) < 0.5)
        #expect(images.allSatisfy { $0.identity.digest.count == 64 })
        #expect(images.allSatisfy { $0.identity.thumbnail.count == 16 * 24 })
        #expect(images[0].identity.digest != images[1].identity.digest)
    }

    @Test func givesTheSameImageTheSameIdentity() throws {
        let image = artImage()
        let data = makePDF(pages: [{ context in
            context.draw(image, in: CGRect(x: 10, y: 20, width: 60, height: 90))
            context.draw(image, in: CGRect(x: 100, y: 20, width: 60, height: 90))
        }])
        let images = PageScanner.scan(try #require(document(data).page(at: 1))).images
        #expect(images.count == 2 && images[0].identity == images[1].identity)
    }

    @Test func leavesTheThumbnailEmptyForUnknownColorSpaces() {
        let content = "q 10 0 0 10 0 0 cm BI /W 1 /H 1 /BPC 8 /CS /Indexed ID x EI Q"
        #expect(EmbeddedImage.thumbnail(of: artImage()).count == 16 * 24)
        #expect(PageScanner.scan(rawPDF(content: content).page(at: 1)!).images.isEmpty)
    }
}

@Suite struct ArtFingerprintTests {
    let thumbnail = EmbeddedImage.thumbnail(of: artImage())

    @Test func keepsEachDigestOnceInOrder() {
        #expect(ArtFingerprint(imageDigests: ["b", "a", "b"]).imageDigests == ["a", "b"])
    }

    @Test func matchesTheSameImages() {
        #expect(ArtFingerprint(imageDigests: ["a", "b"]).matches(ArtFingerprint(imageDigests: ["b", "a"])))
        #expect(!ArtFingerprint(imageDigests: ["a"]).matches(ArtFingerprint(imageDigests: ["b"])))
    }

    @Test func neverMatchesArtWithoutImages() {
        #expect(!ArtFingerprint(imageDigests: []).matches(ArtFingerprint(imageDigests: [])))
    }

    @Test func matchesTheSameArtEncodedAgain() {
        let original = ArtFingerprint(imageDigests: ["a"], thumbnail: thumbnail)
        let reencoded = ArtFingerprint(imageDigests: ["b"],
                                       thumbnail: EmbeddedImage.thumbnail(of: jpegImage(artImage(), quality: 0.5)))
        let different = ArtFingerprint(imageDigests: ["c"],
                                       thumbnail: EmbeddedImage.thumbnail(of: artImage(variant: 2)))
        #expect(original.matches(reencoded))
        #expect(!original.matches(different))
    }

    @Test func matchesABackThatEmbedsTheArtMirrored() {
        let front = ArtFingerprint(imageDigests: ["a"], thumbnail: thumbnail)
        let back = ArtFingerprint(imageDigests: ["b"],
                                  thumbnail: EmbeddedImage.thumbnail(of: horizontallyFlipped(artImage())))
        let different = ArtFingerprint(imageDigests: ["c"],
                                       thumbnail: EmbeddedImage.thumbnail(of: artImage(variant: 2)))
        #expect(!front.matches(back))
        #expect(front.matchesBack(back) && front.matchesBack(front))
        #expect(!front.matchesBack(different))
    }

    @Test func flipsOnlyWholeThumbnails() {
        let odd = ArtFingerprint(imageDigests: ["a"], thumbnail: [1, 2, 3])
        #expect(odd.horizontallyFlipped == odd)
        #expect(ArtFingerprint(imageDigests: ["a"]).horizontallyFlipped.thumbnail.isEmpty)
    }

    @Test func measuresThumbnailDistanceByCorrelation() {
        let same = ArtFingerprint(imageDigests: ["a"], thumbnail: thumbnail)
        let inverted = ArtFingerprint(imageDigests: ["b"], thumbnail: thumbnail.map { 255 - $0 })
        #expect(same.thumbnailDistance(from: same) < 0.001)
        #expect(abs(same.thumbnailDistance(from: inverted) - 200) < 0.001)
        #expect(same.thumbnailDistance(from: ArtFingerprint(imageDigests: ["c"])) == .infinity)
        let flat = ArtFingerprint(imageDigests: ["d"], thumbnail: Array(repeating: 9, count: thumbnail.count))
        #expect(flat.thumbnailDistance(from: flat) == 0)
        #expect(flat.thumbnailDistance(from: same) == .infinity)
    }

    @Test func takesTheArtInsideTheOutline() {
        let art = ImagePlacement(rect: CGRect(x: 0, y: 0, width: 90, height: 150),
                                 identity: ImageIdentity(digest: "art", thumbnail: thumbnail))
        let badge = ImagePlacement(rect: CGRect(x: 10, y: 10, width: 9, height: 9),
                                   identity: ImageIdentity(digest: "badge", thumbnail: []))
        let neighbor = ImagePlacement(rect: CGRect(x: 100, y: 0, width: 90, height: 150),
                                      identity: ImageIdentity(digest: "neighbor", thumbnail: []))
        let outline = CGRect(x: 5, y: 5, width: 81, height: 138)
        let fingerprint = ArtFingerprint(images: [art, badge, neighbor], inside: outline)
        #expect(fingerprint.imageDigests == ["art"])
        #expect(fingerprint.thumbnail == thumbnail)
    }
}
