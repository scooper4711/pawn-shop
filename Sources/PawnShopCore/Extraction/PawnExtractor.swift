import CoreGraphics
import Foundation
import PDFKit

/// A distinct pawn found in a PDF: one piece of art with one name, however many copies were printed.
public struct ExtractedPawn: Equatable, Sendable {
    public var name: String
    public var size: PawnSize
    public var front: PawnFace
    public var back: PawnFace
    public var fingerprint: ArtFingerprint
    /// How many copies the PDF prints.
    public var copies: Int
}

/// A cut outline with no name printed in it.
public struct UnnamedOutline: Equatable, Sendable {
    public let pageIndex: Int
    public let rect: CGRect
}

public struct ExtractionResult: Sendable {
    public var pawns: [ExtractedPawn] = []
    public var unnamed: [UnnamedOutline] = []
}

public enum PawnExtractionError: Error, Equatable, CustomStringConvertible {
    case unreadable(String)

    public var description: String {
        switch self {
        case .unreadable(let file): "Pawn extraction failed: \(file) could not be opened as a PDF"
        }
    }
}

/// Finds the pawns in a Paizo pawn PDF, with their names, sizes and backs.
public enum PawnExtractor {
    public static func extract(from url: URL) throws -> ExtractionResult {
        guard let document = PDFDocument(url: url), let first = document.page(at: 0)?.pageRef,
              let cgDocument = first.document
        else { throw PawnExtractionError.unreadable(url.lastPathComponent) }
        return extract(from: cgDocument, labels: PDFKitLabelReader(document: document))
    }

    static func extract(from document: CGPDFDocument, labels: LabelReader) -> ExtractionResult {
        var result = ExtractionResult()
        for found in outlinedPawns(in: document) {
            guard let size = PawnSize.classify(found.front.uprightSize) else { continue }
            let name = PawnLabel.name(from: labels.runs(onPage: found.front.pageIndex, in: found.front.rect))
            if name.isEmpty {
                result.unnamed.append(UnnamedOutline(pageIndex: found.front.pageIndex, rect: found.front.rect))
            }
            add(ExtractedPawn(name: name, size: size, front: found.front, back: found.back,
                              fingerprint: found.fingerprint, copies: 1), to: &result.pawns)
        }
        numberUnnamed(&result.pawns)
        return result
    }

    /// Some products print no names; their pawns are numbered so they can still be listed and renamed.
    private static func numberUnnamed(_ pawns: inout [ExtractedPawn]) {
        var number = 0
        for index in pawns.indices where pawns[index].name.isEmpty {
            number += 1
            pawns[index].name = "Unnamed \(number)"
        }
    }

    /// A pawn's faces and art, before its label is read.
    struct FoundPawn {
        let front: PawnFace
        let back: PawnFace
        let fingerprint: ArtFingerprint
    }

    /// Every outlined pawn, with its back from the mirrored page that follows, or else its front mirrored.
    static func outlinedPawns(in document: CGPDFDocument) -> [FoundPawn] {
        let pages = (0..<document.numberOfPages).map { index in
            var content = document.page(at: index + 1).map(PageScanner.scan) ?? PageContent()
            content.outlines = content.outlines.filter { $0.size != nil }
            return content
        }
        var found: [FoundPawn] = []
        var pageIndex = 0
        while pageIndex < pages.count {
            let fronts = pages[pageIndex].outlines
            let following = pageIndex + 1 < pages.count ? pages[pageIndex + 1].outlines : []
            let backs = PagePairing.backs(for: fronts, among: following)
            for (front, back) in zip(fronts, backs ?? Array(repeating: nil, count: fronts.count)) {
                let frontFace = PawnFace(pageIndex: pageIndex, rect: front.rect, rotation: front.uprightRotation)
                let backFace = back.map {
                    PawnFace(pageIndex: pageIndex + 1, rect: $0.rect, rotation: $0.uprightRotation)
                }
                found.append(FoundPawn(front: frontFace, back: backFace ?? frontFace.mirroredCopy(),
                                       fingerprint: ArtFingerprint(images: pages[pageIndex].images,
                                                                   inside: front.rect)))
            }
            pageIndex += backs == nil ? 1 : 2
        }
        return found
    }

    /// Counts a copy when the same name, size and art is already listed.
    private static func add(_ pawn: ExtractedPawn, to pawns: inout [ExtractedPawn]) {
        if let index = pawns.firstIndex(where: {
            $0.name == pawn.name && $0.size == pawn.size && $0.fingerprint.matches(pawn.fingerprint)
        }) {
            pawns[index].copies += 1
        } else {
            pawns.append(pawn)
        }
    }
}

/// Matches the outlines of a front page with those of a back page printed mirror image for duplex.
enum PagePairing {
    static let tolerance: CGFloat = 3

    /// The back outline of each front, or nil when `candidates` is not the fronts' back page.
    static func backs(for fronts: [Outline], among candidates: [Outline]) -> [Outline?]? {
        guard !fronts.isEmpty, let axis = mirrorAxis(fronts, candidates) else { return nil }
        let backs = fronts.map { front in
            candidates.first { isMirror($0, of: front, axis: axis) }
        }
        return backs.compactMap { $0 }.count * 2 >= fronts.count ? backs : nil
    }

    /// The most common sum of mirrored centers (twice the axis), over same-size outlines in the same row.
    static func mirrorAxis(_ fronts: [Outline], _ backs: [Outline]) -> CGFloat? {
        var sums: [CGFloat] = []
        for front in fronts {
            for back in backs where back.size == front.size && abs(back.rect.minY - front.rect.minY) < tolerance {
                sums.append(front.rect.midX + back.rect.midX)
            }
        }
        return sums.max { first, second in
            sums.count { abs($0 - first) < tolerance } < sums.count { abs($0 - second) < tolerance }
        }
    }

    static func isMirror(_ back: Outline, of front: Outline, axis: CGFloat) -> Bool {
        back.size == front.size && abs(back.rect.minY - front.rect.minY) < tolerance
            && abs(axis - front.rect.midX - back.rect.midX) < tolerance
    }
}
