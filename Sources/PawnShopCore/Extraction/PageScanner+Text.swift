import CoreGraphics

/// The text operators: where each piece of text is shown, decoded through its font.
extension PageScanner {
    func registerTextOperators() {
        CGPDFOperatorTableSetCallback(operators, "BT") { _, info in PageScanner.from(info).text.begin() }
        CGPDFOperatorTableSetCallback(operators, "Tm") { scanner, info in
            guard let values = PageScanner.popNumbers(scanner, count: 6) else { return }
            PageScanner.from(info).text.setMatrix(PageScanner.matrix(values))
        }
        for name in ["Td", "TD"] {
            CGPDFOperatorTableSetCallback(operators, name) { scanner, info in
                guard let values = PageScanner.popNumbers(scanner, count: 2) else { return }
                PageScanner.from(info).text.moveLine(by: CGPoint(x: values[0], y: values[1]))
            }
        }
        for name in ["Tj", "'", "\""] {
            CGPDFOperatorTableSetCallback(operators, name) { scanner, info in
                let pageScanner = PageScanner.from(info)
                pageScanner.show(pageScanner.text.popString(scanner))
            }
        }
        CGPDFOperatorTableSetCallback(operators, "TJ") { scanner, info in
            let pageScanner = PageScanner.from(info)
            pageScanner.show(pageScanner.text.popArray(scanner))
        }
        CGPDFOperatorTableSetCallback(operators, "Tf") { scanner, info in PageScanner.from(info).setFont(scanner) }
    }

    /// `Tf`: the size is ignored; the font gives the decoder.
    private func setFont(_ scanner: CGPDFScannerRef) {
        var size: CGPDFReal = 0
        var namePointer: UnsafePointer<CChar>?
        guard CGPDFScannerPopNumber(scanner, &size), CGPDFScannerPopName(scanner, &namePointer), let namePointer,
              let object = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner), "Font", namePointer)
        else { return }
        var font: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(object, .dictionary, &font), let font else { return }
        let key = unsafeBitCast(font, to: Int.self)
        let decoder = decoders[key] ?? FontDecoder(font: font)
        decoders[key] = decoder
        text.decoder = decoder
    }

    private func show(_ string: String) {
        guard !string.isEmpty else { return }
        content.glyphs.append(text.glyph(string, transform: transform))
    }
}
