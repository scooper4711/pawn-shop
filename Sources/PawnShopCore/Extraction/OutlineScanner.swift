import CoreGraphics
import Foundation

/// Walks a page's content stream, tracking the transformation matrix, and records the stroked pawn outlines.
final class OutlineScanner {
    private static let maximumFormDepth = 8

    private var transform = CGAffineTransform.identity
    private var savedTransforms: [CGAffineTransform] = []
    private var formDepth = 0
    private var subpaths: [Subpath] = []
    private var outlines: [Outline] = []
    private let operators: CGPDFOperatorTableRef

    /// The pawn outlines stroked on `page`, in page space and drawing order.
    static func outlines(on page: CGPDFPage) -> [Outline] {
        let scanner = OutlineScanner()
        let stream = CGPDFContentStreamCreateWithPage(page)
        scanner.scan(stream)
        CGPDFContentStreamRelease(stream)
        return scanner.outlines
    }

    private init() {
        operators = CGPDFOperatorTableCreate()!
        registerStateOperators()
        registerPathOperators()
        registerPaintOperators()
    }

    deinit { CGPDFOperatorTableRelease(operators) }

    private func registerStateOperators() {
        CGPDFOperatorTableSetCallback(operators, "q") { _, info in OutlineScanner.from(info).saveState() }
        CGPDFOperatorTableSetCallback(operators, "Q") { _, info in OutlineScanner.from(info).restoreState() }
        CGPDFOperatorTableSetCallback(operators, "cm") { scanner, info in
            OutlineScanner.from(info).concatenateMatrix(scanner)
        }
        CGPDFOperatorTableSetCallback(operators, "Do") { scanner, info in
            OutlineScanner.from(info).drawXObject(scanner)
        }
    }

    private func registerPathOperators() {
        CGPDFOperatorTableSetCallback(operators, "m") { scanner, info in OutlineScanner.from(info).moveTo(scanner) }
        CGPDFOperatorTableSetCallback(operators, "l") { scanner, info in OutlineScanner.from(info).lineTo(scanner) }
        CGPDFOperatorTableSetCallback(operators, "c") { scanner, info in
            OutlineScanner.from(info).curveTo(scanner, count: 3, repeatsStart: false)
        }
        CGPDFOperatorTableSetCallback(operators, "v") { scanner, info in
            OutlineScanner.from(info).curveTo(scanner, count: 2, repeatsStart: true)
        }
        CGPDFOperatorTableSetCallback(operators, "y") { scanner, info in
            OutlineScanner.from(info).curveTo(scanner, count: 2, repeatsStart: false)
        }
        CGPDFOperatorTableSetCallback(operators, "re") { scanner, info in
            OutlineScanner.from(info).rectangle(scanner)
        }
    }

    private func registerPaintOperators() {
        for name in ["S", "s", "B", "B*", "b", "b*"] {
            CGPDFOperatorTableSetCallback(operators, name) { _, info in OutlineScanner.from(info).stroke() }
        }
        for name in ["f", "F", "f*", "n"] {
            CGPDFOperatorTableSetCallback(operators, name) { _, info in OutlineScanner.from(info).endPath() }
        }
    }

    private static func from(_ info: UnsafeMutableRawPointer?) -> OutlineScanner {
        Unmanaged<OutlineScanner>.fromOpaque(info!).takeUnretainedValue()
    }

    private func scan(_ stream: CGPDFContentStreamRef) {
        let scanner = CGPDFScannerCreate(stream, operators, Unmanaged.passUnretained(self).toOpaque())
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
    }

    // MARK: Graphics state

    private func saveState() { savedTransforms.append(transform) }

    private func restoreState() { transform = savedTransforms.popLast() ?? transform }

    private func concatenateMatrix(_ scanner: CGPDFScannerRef) {
        guard let values = Self.popNumbers(scanner, count: 6) else { return }
        transform = Self.matrix(values).concatenating(transform)
    }

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
        outlines += subpaths.compactMap { $0.outline() }
        subpaths.removeAll()
    }

    private func endPath() { subpaths.removeAll() }

    private func popPoints(_ scanner: CGPDFScannerRef, count: Int) -> [CGPoint]? {
        guard let values = Self.popNumbers(scanner, count: count * 2) else { return nil }
        return stride(from: 0, to: values.count, by: 2).map {
            CGPoint(x: values[$0], y: values[$0 + 1]).applying(transform)
        }
    }

    /// Operands in the order written; the scanner pops them last first.
    private static func popNumbers(_ scanner: CGPDFScannerRef, count: Int) -> [CGFloat]? {
        var values = [CGPDFReal](repeating: 0, count: count)
        for index in stride(from: count - 1, through: 0, by: -1) {
            guard CGPDFScannerPopNumber(scanner, &values[index]) else { return nil }
        }
        return values
    }

    // MARK: Form XObjects

    private func drawXObject(_ scanner: CGPDFScannerRef) {
        var namePointer: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &namePointer), let namePointer,
              let stream = CGPDFScannerGetContentStream(scanner) as CGPDFContentStreamRef?,
              let object = CGPDFContentStreamGetResource(stream, "XObject", namePointer)
        else { return }

        var xObject: CGPDFStreamRef?
        guard CGPDFObjectGetValue(object, .stream, &xObject), let xObject,
              let dictionary = CGPDFStreamGetDictionary(xObject),
              Self.name(in: dictionary, key: "Subtype") == "Form"
        else { return }
        scanForm(xObject, dictionary: dictionary, parent: stream)
    }

    private func scanForm(_ stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef, parent: CGPDFContentStreamRef) {
        guard formDepth < Self.maximumFormDepth else { return }
        var resources: CGPDFDictionaryRef?
        _ = CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources)

        let saved = (transform, savedTransforms, subpaths)
        transform = Self.formMatrix(dictionary).concatenating(transform)
        subpaths = []
        formDepth += 1
        let formStream = CGPDFContentStreamCreateWithStream(stream, resources ?? dictionary, parent)
        scan(formStream)
        CGPDFContentStreamRelease(formStream)
        formDepth -= 1
        (transform, savedTransforms, subpaths) = saved
    }

    private static func formMatrix(_ dictionary: CGPDFDictionaryRef) -> CGAffineTransform {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "Matrix", &array), let array, CGPDFArrayGetCount(array) == 6
        else { return .identity }
        var values = [CGPDFReal](repeating: 0, count: 6)
        for index in 0..<6 { _ = CGPDFArrayGetNumber(array, index, &values[index]) }
        return matrix(values)
    }

    private static func matrix(_ values: [CGFloat]) -> CGAffineTransform {
        CGAffineTransform(a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5])
    }

    private static func name(in dictionary: CGPDFDictionaryRef, key: String) -> String? {
        var pointer: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, key, &pointer), let pointer else { return nil }
        return String(cString: pointer)
    }
}
