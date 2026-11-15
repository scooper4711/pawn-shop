import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The image on the clipboard, for Add Custom Pawn: image data, as Pluck copies it, or a copied image file.
@MainActor
enum ImagePasteboard {
    static var hasImage: Bool {
        #if os(macOS)
        NSImage.canInit(with: .general)
        #else
        UIPasteboard.general.hasImages
        #endif
    }

    /// A copied file, which keeps its name for the pawn.
    static var fileURL: URL? {
        #if os(macOS)
        (NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL])?.first
        #else
        UIPasteboard.general.url.flatMap { $0.isFileURL ? $0 : nil }
        #endif
    }

    static var image: CGImage? {
        #if os(macOS)
        NSImage(pasteboard: NSPasteboard.general)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        UIPasteboard.general.image?.cgImage
        #endif
    }
}
