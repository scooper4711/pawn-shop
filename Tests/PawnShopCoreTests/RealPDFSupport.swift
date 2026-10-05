import CoreGraphics
import Foundation

/// Paizo pawn PDFs copied (or linked) into the gitignored `TestData/` folder; empty when there are none.
enum RealPDFs {
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("TestData")

    static var all: [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.lowercased().hasSuffix(".pdf") }.sorted().map { folder.appendingPathComponent($0) }
    }

    static var isAvailable: Bool { !all.isEmpty }

    /// The first PDF whose name contains `fragment`.
    static func named(_ fragment: String) -> URL? {
        all.first { $0.lastPathComponent.contains(fragment) }
    }

    static func document(_ url: URL) -> CGPDFDocument? {
        CGPDFDocument(url as CFURL)
    }
}
