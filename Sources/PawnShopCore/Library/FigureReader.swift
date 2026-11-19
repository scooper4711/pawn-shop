import CoreGraphics
import ArtExtraction
import Foundation

/// Finds the figure a pawn's art shows (see `Figure`) in the library's copies of its PDFs. It keeps the last few
/// PDFs, pages and figures it has read, since an open PDF holds on to the pictures it decoded and a picture can
/// take megabytes; reading one again takes some 20 ms. Each reader must stay on one thread.
final class FigureReader {
    static let keptDocuments = 8
    static let keptPages = 24
    static let keptFigures = 24

    /// A page's pictures with the PDF they were read from. A picture's stream is part of its PDF and gone once
    /// that closes, so a kept page keeps its PDF open, however few PDFs are kept open for reading new pages.
    private struct ReadPage {
        let document: CGPDFDocument
        let images: [ImagePlacement]
    }

    private let folders: LibraryFolders
    private let documents = BoundedCache<CGPDFDocument>(countLimit: keptDocuments)
    private let pages = BoundedCache<ReadPage>(countLimit: keptPages)
    private let figures = BoundedCache<Figure>(countLimit: keptFigures)

    init(folders: LibraryFolders) {
        self.folders = folders
    }

    /// The figure a Battle Card pawn draws.
    func figure(of art: CardArt) -> Figure? {
        figure(source: art.sourceID, face: art.face, imageIndex: art.imageIndex)
    }

    /// The figure a pawn shows: a card's creature, or the largest picture on a printed pawn's front. Nil for
    /// custom art, tokens and saved pictures, which are drawn from files and not from a PDF.
    func figure(of pawn: Pawn) -> Figure? {
        switch pawn.art {
        case .card(let art): figure(of: art)
        case .pdf(let sourceID, let front, _): figure(source: sourceID, face: front, imageIndex: nil)
        case .custom, .token, .picture: nil
        }
    }

    /// The figure of a pawn just extracted from the imported PDF `sourceID`; nil for tokens.
    func figure(of found: ExtractedPawn, source sourceID: String) -> Figure? {
        switch found.shape {
        case .card(let index), .item(let index): figure(source: sourceID, face: found.front, imageIndex: index)
        case .pawn: figure(source: sourceID, face: found.front, imageIndex: nil)
        case .token, .drawnItem: nil
        }
    }

    /// The picture of an item from a PDF deck; nil for one cut out of a deck sold as pictures, which is a PNG.
    func figure(of artwork: ItemArtwork) -> Figure? {
        guard case .figure(let face, let imageIndex) = artwork.picture else { return nil }
        return figure(source: artwork.sourceID, face: face, imageIndex: imageIndex)
    }

    /// Forgets the pages read, which hold on to their PDFs' pictures.
    func forgetPages() {
        pages.removeAll()
        figures.removeAll()
    }

    /// The picture drawn `imageIndex`th on the face's page, cut to the face; or with no index, the largest
    /// picture inside the face, trimmed.
    private func figure(source: String, face: PawnFace, imageIndex: Int?) -> Figure? {
        let key = "\(source)/\(face.pageIndex)/\(imageIndex.map(String.init) ?? "\(face.rect)")"
        return figures.value(for: key) {
            guard let page = page(source: source, pageIndex: face.pageIndex) else { return nil }
            // The figure is decoded from its picture's stream, so the PDF stays open until it is made.
            return withExtendedLifetime(page.document) {
                let images = page.images
                guard let imageIndex else { return Figure.largest(inside: face.rect, among: images) }
                return images.indices.contains(imageIndex) ? Self.figure(images[imageIndex], bounds: face.rect) : nil
            }
        }
    }

    /// The picture with its known bounds, without trimming it again.
    private static func figure(_ placement: ImagePlacement, bounds: CGRect) -> Figure? {
        placement.stream.flatMap(EmbeddedImage.maskedImage(of:))
            .map { Figure(placement: placement, image: $0, bounds: bounds) }
    }

    private func page(source: String, pageIndex: Int) -> ReadPage? {
        pages.value(for: "\(source)/\(pageIndex)") {
            guard let document = document(source), let page = document.page(at: pageIndex + 1) else { return nil }
            return ReadPage(document: document, images: PageScanner.images(on: page))
        }
    }

    private func document(_ source: String) -> CGPDFDocument? {
        documents.value(for: source) { CGPDFDocument(folders.sourceFile(id: source) as CFURL) }
    }
}
