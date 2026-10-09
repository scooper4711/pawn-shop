import CoreGraphics
import Foundation

/// An image drawn on a page.
struct ImagePlacement: Equatable {
    /// Bounds in page space.
    let rect: CGRect
    /// What the image shows.
    let identity: ImageIdentity
    /// The circle the image is clipped to, as round tokens are; nil when it isn't clipped to one.
    var clip: Circle?
    /// Maps the image's unit square onto the page.
    var transform = CGAffineTransform.identity
    /// The image XObject, valid while its document is open.
    var stream: CGPDFStreamRef?
}

/// The pawn outlines, images and text on a page.
struct PageContent {
    var outlines: [Outline] = []
    var images: [ImagePlacement] = []
    var glyphs: [TextGlyph] = []
}

/// Walks a page's content stream, tracking the transformation matrix and circular clips, and records the
/// stroked pawn outlines, the images drawn and the text shown.
final class PageScanner {
    private static let maximumFormDepth = 8

    /// What `q` saves and `Q` restores.
    private struct GraphicsState {
        var transform = CGAffineTransform.identity
        var clip: Circle?
    }

    private var state = GraphicsState()
    private var savedStates: [GraphicsState] = []
    /// True between `W` and the painting operator that makes the current path the clip.
    private var clipPending = false
    var text = TextState()
    /// Decoders of the fonts used so far, by font dictionary.
    var decoders: [Int: FontDecoder] = [:]
    private var formDepth = 0
    private var subpaths: [Subpath] = []
    var content = PageContent()
    private var identities: [Int: ImageIdentity] = [:]
    /// False when only where images are drawn is wanted, not what they show, which is slower to work out.
    private var identifiesImages = true
    let operators: CGPDFOperatorTableRef

    /// The pawn outlines stroked and the images drawn on `page`, in page space and drawing order.
    static func scan(_ page: CGPDFPage) -> PageContent {
        let scanner = PageScanner()
        let stream = CGPDFContentStreamCreateWithPage(page)
        scanner.scan(stream)
        CGPDFContentStreamRelease(stream)
        return scanner.content
    }

    /// The images drawn on `page`, in page space and drawing order, without their identities.
    static func images(on page: CGPDFPage) -> [ImagePlacement] {
        let scanner = PageScanner()
        scanner.identifiesImages = false
        let stream = CGPDFContentStreamCreateWithPage(page)
        scanner.scan(stream)
        CGPDFContentStreamRelease(stream)
        return scanner.content.images
    }

    /// The pawn outlines stroked on `page`.
    static func outlines(on page: CGPDFPage) -> [Outline] { scan(page).outlines }

    private init() {
        operators = CGPDFOperatorTableCreate()!
        registerStateOperators()
        registerPathOperators()
        registerPaintOperators()
        registerTextOperators()
    }

    deinit { CGPDFOperatorTableRelease(operators) }

    private func registerStateOperators() {
        CGPDFOperatorTableSetCallback(operators, "q") { _, info in PageScanner.from(info).saveState() }
        CGPDFOperatorTableSetCallback(operators, "Q") { _, info in PageScanner.from(info).restoreState() }
        CGPDFOperatorTableSetCallback(operators, "cm") { scanner, info in
            PageScanner.from(info).concatenateMatrix(scanner)
        }
        CGPDFOperatorTableSetCallback(operators, "Do") { scanner, info in
            PageScanner.from(info).drawXObject(scanner)
        }
    }

    private func registerPathOperators() {
        CGPDFOperatorTableSetCallback(operators, "m") { scanner, info in PageScanner.from(info).moveTo(scanner) }
        CGPDFOperatorTableSetCallback(operators, "l") { scanner, info in PageScanner.from(info).lineTo(scanner) }
        CGPDFOperatorTableSetCallback(operators, "c") { scanner, info in
            PageScanner.from(info).curveTo(scanner, count: 3, repeatsStart: false)
        }
        CGPDFOperatorTableSetCallback(operators, "v") { scanner, info in
            PageScanner.from(info).curveTo(scanner, count: 2, repeatsStart: true)
        }
        CGPDFOperatorTableSetCallback(operators, "y") { scanner, info in
            PageScanner.from(info).curveTo(scanner, count: 2, repeatsStart: false)
        }
        CGPDFOperatorTableSetCallback(operators, "re") { scanner, info in
            PageScanner.from(info).rectangle(scanner)
        }
    }

    private func registerPaintOperators() {
        for name in ["S", "s", "B", "B*", "b", "b*"] {
            CGPDFOperatorTableSetCallback(operators, name) { _, info in PageScanner.from(info).stroke() }
        }
        for name in ["f", "F", "f*", "n"] {
            CGPDFOperatorTableSetCallback(operators, name) { _, info in PageScanner.from(info).endPath() }
        }
        for name in ["W", "W*"] {
            CGPDFOperatorTableSetCallback(operators, name) { _, info in PageScanner.from(info).clipPending = true }
        }
    }

    static func from(_ info: UnsafeMutableRawPointer?) -> PageScanner {
        Unmanaged<PageScanner>.fromOpaque(info!).takeUnretainedValue()
    }

    private func scan(_ stream: CGPDFContentStreamRef) {
        let scanner = CGPDFScannerCreate(stream, operators, Unmanaged.passUnretained(self).toOpaque())
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
    }

    // MARK: Graphics state

    private func saveState() { savedStates.append(state) }

    private func restoreState() { state = savedStates.popLast() ?? state }

    private func concatenateMatrix(_ scanner: CGPDFScannerRef) {
        guard let values = Self.popNumbers(scanner, count: 6) else { return }
        state.transform = Self.matrix(values).concatenating(state.transform)
    }

    var transform: CGAffineTransform { state.transform }

    // MARK: Paths

    private func moveTo(_ scanner: CGPDFScannerRef) {
        guard let point = popPoints(scanner, count: 1)?.first else { return }
        var subpath = Subpath()
        subpath.add(line: point)
        subpaths.append(subpath)
    }

    private func lineTo(_ scanner: CGPDFScannerRef) {
        guard let point = popPoints(scanner, count: 1)?.first, !subpaths.isEmpty else { return }
        subpaths[subpaths.count - 1].add(line: point)
    }

    /// `c` has two control points; `v` repeats the current point as the first, `y` the end point as the second.
    private func curveTo(_ scanner: CGPDFScannerRef, count: Int, repeatsStart: Bool) {
        guard let points = popPoints(scanner, count: count), !subpaths.isEmpty else { return }
        let end = points[points.count - 1]
        var controls = Array(points.dropLast())
        if count == 2, repeatsStart, let start = subpaths[subpaths.count - 1].lastPoint {
            controls.insert(start, at: 0)
        }
        subpaths[subpaths.count - 1].add(curveTo: end, controls: controls)
    }

    private func rectangle(_ scanner: CGPDFScannerRef) {
        guard let values = Self.popNumbers(scanner, count: 4) else { return }
        let corners = [CGPoint(x: values[0], y: values[1]), CGPoint(x: values[0] + values[2], y: values[1]),
                       CGPoint(x: values[0] + values[2], y: values[1] + values[3]),
                       CGPoint(x: values[0], y: values[1] + values[3])]
        var subpath = Subpath()
        corners.forEach { subpath.add(line: $0.applying(transform)) }
        subpaths.append(subpath)
    }

    private func stroke() {
        content.outlines += subpaths.compactMap { $0.outline() }
        endPath()
    }

    /// Ends the path, making it the clip when `W` asked: a single circle becomes the clip images are drawn in.
    /// Another clip inside a circle keeps the circle.
    private func endPath() {
        if clipPending, subpaths.count == 1, let circle = subpaths[0].circle() {
            state.clip = circle
        }
        clipPending = false
        subpaths.removeAll()
    }

    private func popPoints(_ scanner: CGPDFScannerRef, count: Int) -> [CGPoint]? {
        guard let values = Self.popNumbers(scanner, count: count * 2) else { return nil }
        return stride(from: 0, to: values.count, by: 2).map {
            CGPoint(x: values[$0], y: values[$0 + 1]).applying(transform)
        }
    }

    /// Operands in the order written; the scanner pops them last first.
    static func popNumbers(_ scanner: CGPDFScannerRef, count: Int) -> [CGFloat]? {
        var values = [CGPDFReal](repeating: 0, count: count)
        for index in stride(from: count - 1, through: 0, by: -1) {
            guard CGPDFScannerPopNumber(scanner, &values[index]) else { return nil }
        }
        return values
    }

    // MARK: XObjects

    private func drawXObject(_ scanner: CGPDFScannerRef) {
        var namePointer: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &namePointer), let namePointer,
              let stream = CGPDFScannerGetContentStream(scanner) as CGPDFContentStreamRef?,
              let object = CGPDFContentStreamGetResource(stream, "XObject", namePointer)
        else { return }

        var xObject: CGPDFStreamRef?
        guard CGPDFObjectGetValue(object, .stream, &xObject), let xObject,
              let dictionary = CGPDFStreamGetDictionary(xObject)
        else { return }
        switch Self.name(in: dictionary, key: "Subtype") {
        case "Form": scanForm(xObject, dictionary: dictionary, parent: stream)
        case "Image": recordImage(xObject)
        default: break
        }
    }

    private func recordImage(_ stream: CGPDFStreamRef) {
        let key = unsafeBitCast(stream, to: Int.self)
        let identity = identities[key] ?? (identifiesImages ? EmbeddedImage.identity(of: stream) : .empty)
        identities[key] = identity
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1).applying(transform)
        content.images.append(ImagePlacement(rect: rect, identity: identity, clip: state.clip, transform: transform,
                                             stream: stream))
    }

    private func scanForm(_ stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef, parent: CGPDFContentStreamRef) {
        guard formDepth < Self.maximumFormDepth else { return }
        var resources: CGPDFDictionaryRef?
        _ = CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources)

        let saved = (state, savedStates, subpaths)
        state.transform = Self.formMatrix(dictionary).concatenating(transform)
        subpaths = []
        formDepth += 1
        let formStream = CGPDFContentStreamCreateWithStream(stream, resources ?? dictionary, parent)
        scan(formStream)
        CGPDFContentStreamRelease(formStream)
        formDepth -= 1
        (state, savedStates, subpaths) = saved
    }

    private static func formMatrix(_ dictionary: CGPDFDictionaryRef) -> CGAffineTransform {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "Matrix", &array), let array, CGPDFArrayGetCount(array) == 6
        else { return .identity }
        var values = [CGPDFReal](repeating: 0, count: 6)
        for index in 0..<6 { _ = CGPDFArrayGetNumber(array, index, &values[index]) }
        return matrix(values)
    }

    static func matrix(_ values: [CGFloat]) -> CGAffineTransform {
        CGAffineTransform(a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5])
    }

    private static func name(in dictionary: CGPDFDictionaryRef, key: String) -> String? {
        var pointer: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, key, &pointer), let pointer else { return nil }
        return String(cString: pointer)
    }
}
