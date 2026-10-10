import CoreGraphics
import ArtExtraction
import Foundation

/// Finds the figure a pawn's art shows (see `Figure`) in the library's copies of its PDFs. It keeps the PDFs
/// and pages it has read, and its last few figures, since a decoded picture can take megabytes. Each reader must
/// stay on one thread.
final class FigureReader {
    static let keptFigures = 24

    private let folders: LibraryFolders
    private var documents: [String: CGPDFDocument] = [:]
    private var pages: [String: [ImagePlacement]] = [:]
    private let figures = NSCache<NSString, FigureBox>()

    init(folders: LibraryFolders) {
        self.folders = folders
        figures.countLimit = Self.keptFigures
    }

    /// The figure a Battle Card pawn draws.
    func figure(of art: CardArt) -> Figure? {
        figure(source: art.sourceID, face: art.face, imageIndex: art.imageIndex)
    }

    /// The figure a pawn shows: a card's creature, or the largest picture on a printed pawn's front. Nil for
    /// custom art and tokens, whose pictures are cut round or framed by the user.
    func figure(of pawn: Pawn) -> Figure? {
        switch pawn.art {
        case .card(let art): figure(of: art)
        case .pdf(let sourceID, let front, _): figure(source: sourceID, face: front, imageIndex: nil)
        case .custom, .token: nil
        }
    }

    /// The figure of a pawn just extracted from the imported PDF `sourceID`; nil for tokens.
    func figure(of found: ExtractedPawn, source sourceID: String) -> Figure? {
        switch found.shape {
        case .card(let index): figure(source: sourceID, face: found.front, imageIndex: index)
        case .pawn: figure(source: sourceID, face: found.front, imageIndex: nil)
        case .token: nil
        }
    }

    /// Forgets the pages read, which hold on to their PDFs' pictures.
    func forgetPages() {
        pages.removeAll()
        figures.removeAllObjects()
    }

    /// The picture drawn `imageIndex`th on the face's page, cut to the face; or with no index, the largest
    /// picture inside the face, trimmed.
    private func figure(source: String, face: PawnFace, imageIndex: Int?) -> Figure? {
        let key = "\(source)/\(face.pageIndex)/\(imageIndex.map(String.init) ?? "\(face.rect)")" as NSString
        if let kept = figures.object(forKey: key) { return kept.figure }
        let images = images(source: source, pageIndex: face.pageIndex)
        let figure: Figure?
        if let imageIndex {
            figure = images.indices.contains(imageIndex) ? Self.figure(images[imageIndex], bounds: face.rect) : nil
        } else {
            figure = Figure.largest(inside: face.rect, among: images)
        }
        if let figure { figures.setObject(FigureBox(figure), forKey: key) }
        return figure
    }

    /// The picture with its known bounds, without trimming it again.
    private static func figure(_ placement: ImagePlacement, bounds: CGRect) -> Figure? {
        placement.stream.flatMap(EmbeddedImage.maskedImage(of:))
            .map { Figure(placement: placement, image: $0, bounds: bounds) }
    }

    private func images(source: String, pageIndex: Int) -> [ImagePlacement] {
        let key = "\(source)/\(pageIndex)"
        if let images = pages[key] { return images }
        let images = document(source)?.page(at: pageIndex + 1).map(PageScanner.images(on:)) ?? []
        pages[key] = images
        return images
    }

    private func document(_ source: String) -> CGPDFDocument? {
        if let document = documents[source] { return document }
        let document = CGPDFDocument(folders.sourceFile(id: source) as CFURL)
        documents[source] = document
        return document
    }
}

/// A figure kept in an `NSCache`, which holds only objects.
final class FigureBox {
    let figure: Figure

    init(_ figure: Figure) { self.figure = figure }
}
