import CoreGraphics

/// A round token on a page: art clipped to a circle, which reaches a bleed past the circle it is cut along.
struct FoundToken: Equatable {
    /// The circle the art is clipped to, bleed included.
    let clip: Circle
    /// The images drawn in the clip.
    let images: [ImagePlacement]
    let art: ArtFingerprint
    /// The text shown inside the clip, in drawing order, each piece once.
    let glyphs: [TextGlyph]

    /// By the circle the token is cut along: the clip less the bleed.
    var size: PawnSize { PawnSize.token(diameter: clip.diameter - 2 * TokenFinder.bleed) }

    /// True when words are printed on the token, such as its name along the rim or a label on its back.
    var hasText: Bool { glyphs.contains { $0.text.contains(where: \.isLetter) } }

    /// The words printed on the token as a name: lines without letters (a label's token number), the copyright
    /// line and lines repeating another (a label also set along the rim) are left out. "SMOG SCAMP 2" becomes
    /// "Smog Scamp 2".
    var printedName: String {
        var words: [String] = []
        for line in Self.lines(of: glyphs).map({ $0.trimmingCharacters(in: .whitespaces) })
        where line.contains(where: \.isLetter) && !line.contains("©") && !words.contains(line) {
            words.append(line)
        }
        return PawnLabel.name(from: [LabelRun(text: words.joined(separator: " "), fontSize: 1)])
    }

    /// The text in lines. Text set along a curve is placed one letter at a time, so letters shown one after
    /// another make one line; longer text is a line of its own.
    static func lines(of glyphs: [TextGlyph]) -> [String] {
        var lines: [String] = []
        var previousIsSingle = false
        for glyph in glyphs {
            let isSingle = glyph.text.count == 1
            if isSingle, previousIsSingle, !lines.isEmpty {
                lines[lines.count - 1] += glyph.text
            } else {
                lines.append(glyph.text)
            }
            previousIsSingle = isSingle
        }
        return lines
    }
}

/// Finds the round tokens on a page: circles that clip art, outside any pawn outline.
enum TokenFinder {
    /// Circles smaller than this are badges or decorations, not tokens.
    static let smallestDiameter: CGFloat = 36
    /// Circles larger than this, 4" with bleed, are cover art: Paizo's largest tokens are 4".
    static let largestDiameter: CGFloat = 4 * 72 + 2 * bleed
    /// How far the art reaches past the cut: Paizo's 1/8" bleed.
    static let bleed: CGFloat = 9
    /// Circles this close, in points, are the same circle.
    static let tolerance: CGFloat = 1.5

    static func tokens(on page: PageContent) -> [FoundToken] {
        clips(on: page).compactMap { clip in
            let images = page.images.filter { $0.clip?.isSame(as: clip, tolerance: tolerance) ?? false }
            let art = ArtFingerprint(images: images, inside: clip.bounds)
            guard !art.imageDigests.isEmpty else { return nil }
            return FoundToken(clip: clip, images: images, art: art, glyphs: glyphs(inside: clip, among: page.glyphs))
        }
    }

    /// Each circle images are clipped to, once, in drawing order.
    private static func clips(on page: PageContent) -> [Circle] {
        var clips: [Circle] = []
        for clip in page.images.compactMap(\.clip) where (smallestDiameter...largestDiameter).contains(clip.diameter)
            && !clips.contains(where: { $0.isSame(as: clip, tolerance: tolerance) })
            && !page.outlines.contains(where: { $0.rect.contains(clip.center) }) {
            clips.append(clip)
        }
        return clips
    }

    /// The text starting inside `clip`. Text drawn twice in the same place (an outline and a fill) is kept once.
    private static func glyphs(inside clip: Circle, among glyphs: [TextGlyph]) -> [TextGlyph] {
        var kept: [TextGlyph] = []
        for glyph in glyphs where clip.contains(glyph.origin) && !kept.contains(where: {
            $0.text == glyph.text && hypot($0.origin.x - glyph.origin.x, $0.origin.y - glyph.origin.y) < 0.1
        }) {
            kept.append(glyph)
        }
        return kept
    }
}

/// Matches the tokens of a page with those of the page after it, printed mirror image as their backs.
enum TokenPairing {
    static let tolerance: CGFloat = 3

    /// The back of each front, or nil when `candidates` is not the fronts' back page: at least half the fronts
    /// need a token where their mirror image falls that is their back (see `isBack`).
    static func backs(for fronts: [FoundToken], among candidates: [FoundToken]) -> [FoundToken?]? {
        guard !fronts.isEmpty, let axis = mirrorAxis(fronts, candidates) else { return nil }
        let backs = fronts.map { front in candidates.first { isMirror($0, of: front, axis: axis) } }
        let agreeing = zip(fronts, backs).count { front, back in back.map { isBack($0, of: front) } ?? false }
        return agreeing * 2 >= fronts.count ? backs : nil
    }

    /// True when `back` shows the front's art again, or labels a front that prints no words.
    static func isBack(_ back: FoundToken, of front: FoundToken) -> Bool {
        isLabel(back, of: front) || front.art.matchesBack(back.art)
    }

    /// True when `back` prints the words for a front that has none, as a token box's label side does.
    static func isLabel(_ back: FoundToken, of front: FoundToken) -> Bool {
        !front.hasText && back.hasText && !front.art.matchesBack(back.art)
    }

    /// The most common sum of mirrored centers (twice the axis), over same-size tokens in the same row.
    private static func mirrorAxis(_ fronts: [FoundToken], _ backs: [FoundToken]) -> CGFloat? {
        var sums: [CGFloat] = []
        for front in fronts {
            for back in backs where isSameRowAndSize(back, front) {
                sums.append(front.clip.center.x + back.clip.center.x)
            }
        }
        return sums.max { first, second in
            sums.count { abs($0 - first) < tolerance } < sums.count { abs($0 - second) < tolerance }
        }
    }

    private static func isMirror(_ back: FoundToken, of front: FoundToken, axis: CGFloat) -> Bool {
        isSameRowAndSize(back, front) && abs(axis - front.clip.center.x - back.clip.center.x) < tolerance
    }

    private static func isSameRowAndSize(_ back: FoundToken, _ front: FoundToken) -> Bool {
        abs(back.clip.diameter - front.clip.diameter) < tolerance
            && abs(back.clip.center.y - front.clip.center.y) < tolerance
    }
}

/// A token, with its back when the following page prints one.
struct PairedToken {
    let front: FoundToken
    let back: FoundToken?
    /// The front's page; the back is on the next.
    let pageIndex: Int

    /// The token as a pawn, its art drawn alone; nil when its images can't be decoded. It is named from its label
    /// on the back, or else from the name printed on its art. A back showing the art again gives the back face.
    func extracted() -> ExtractedPawn? {
        guard let frontPicture = TokenPicture.png(of: front) else { return nil }
        let frontFace = PawnFace(pageIndex: pageIndex, rect: front.clip.bounds, rotation: 0)
        var pawn = ExtractedPawn(name: front.printedName, size: front.size, front: frontFace,
                                 back: frontFace.mirroredCopy(), fingerprint: front.art, copies: 1,
                                 shape: .token(TokenPictures(front: frontPicture)))
        guard let back else { return pawn }
        if TokenPairing.isLabel(back, of: front) {
            pawn.name = back.printedName
        } else if let backPicture = TokenPicture.png(of: back) {
            pawn.back = PawnFace(pageIndex: pageIndex + 1, rect: back.clip.bounds, rotation: 0)
            pawn.shape = .token(TokenPictures(front: frontPicture, back: backPicture))
        }
        return pawn
    }
}
