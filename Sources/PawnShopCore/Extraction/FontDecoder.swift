import CoreGraphics
import Foundation

/// Turns the bytes shown in a font into text by the font's ToUnicode map, as PDF readers do. Fonts without one
/// are read as PDF text strings, and codes the map leaves out as Latin-1.
struct FontDecoder {
    /// The text of each character code.
    private let map: [UInt32: String]
    /// Bytes per character code: 1 for simple fonts, 2 for most composite fonts.
    private let codeLength: Int

    static let plain = FontDecoder(map: [:], codeLength: 1)

    private init(map: [UInt32: String], codeLength: Int) {
        self.map = map
        self.codeLength = codeLength
    }

    /// The decoder for a font dictionary; plain when it has no readable ToUnicode map.
    init(font: CGPDFDictionaryRef) {
        var stream: CGPDFStreamRef?
        var format = CGPDFDataFormat.raw
        guard CGPDFDictionaryGetStream(font, "ToUnicode", &stream), let stream,
              let data = CGPDFStreamCopyData(stream, &format) as Data?, format == .raw,
              let cmap = String(data: data, encoding: .isoLatin1)
        else {
            self = .plain
            return
        }
        self = Self.parse(cmap)
    }

    func text(of string: CGPDFStringRef) -> String {
        guard !map.isEmpty, let bytes = CGPDFStringGetBytePtr(string) else {
            return (CGPDFStringCopyTextString(string) as String?) ?? ""
        }
        let count = CGPDFStringGetLength(string)
        return stride(from: 0, to: count - codeLength + 1, by: codeLength).map { start in
            let code = (0..<codeLength).reduce(UInt32(0)) { $0 << 8 | UInt32(bytes[start + $1]) }
            return map[code] ?? String(UnicodeScalar(UInt8(truncatingIfNeeded: code)))
        }.joined()
    }

    // MARK: CMap parsing

    /// Reads the `bfchar` and `bfrange` sections of a ToUnicode CMap.
    static func parse(_ cmap: String) -> FontDecoder {
        var map: [UInt32: String] = [:]
        var codeLength = 1
        for section in sections(of: cmap, named: "bfchar") {
            let tokens = hexTokens(section)
            for index in stride(from: 0, to: tokens.count - 1, by: 2) {
                codeLength = max(codeLength, tokens[index].count / 2)
                map[code(tokens[index])] = text(fromHex: tokens[index + 1])
            }
        }
        for section in sections(of: cmap, named: "bfrange") {
            codeLength = max(codeLength, addRanges(section, to: &map))
        }
        return FontDecoder(map: map, codeLength: codeLength)
    }

    /// Ranges `<low> <high> <first>`, whose codes map to consecutive text, or `<low> <high> [<text> …]`.
    private static func addRanges(_ section: Substring, to map: inout [UInt32: String]) -> Int {
        var codeLength = 1
        let pattern = /<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<[0-9A-Fa-f]+>|\[[^\]]*\])/
        for match in section.matches(of: pattern) {
            let low = code(String(match.1)), high = code(String(match.2))
            codeLength = max(codeLength, match.1.count / 2)
            guard high >= low, high - low < 0x10000 else { continue }
            let destination = hexTokens(match.3)
            for offset in 0...(high - low) {
                if match.3.hasPrefix("[") {
                    if Int(offset) < destination.count { map[low + offset] = text(fromHex: destination[Int(offset)]) }
                } else if let first = destination.first {
                    map[low + offset] = text(fromHex: first, adding: offset)
                }
            }
        }
        return codeLength
    }

    private static func sections(of cmap: String, named name: String) -> [Substring] {
        let parts: [String] = cmap.components(separatedBy: "begin\(name)")
        return parts.dropFirst().compactMap { part in
            part.components(separatedBy: "end\(name)").first.map { Substring($0) }
        }
    }

    private static func hexTokens(_ text: Substring) -> [String] {
        text.matches(of: /<([0-9A-Fa-f]*)>/).map { String($0.1) }
    }

    private static func code(_ hex: String) -> UInt32 { UInt32(hex, radix: 16) ?? 0 }

    /// UTF-16BE hex as text; `adding` raises the last code unit, as a range's consecutive codes do.
    private static func text(fromHex hex: String, adding offset: UInt32 = 0) -> String {
        var units = stride(from: 0, to: hex.count - 3, by: 4).compactMap { start -> UInt16? in
            let begin = hex.index(hex.startIndex, offsetBy: start)
            return UInt16(hex[begin..<hex.index(begin, offsetBy: 4)], radix: 16)
        }
        if let last = units.last { units[units.count - 1] = last &+ UInt16(truncatingIfNeeded: offset) }
        return String(decoding: units, as: UTF16.self)
    }
}
