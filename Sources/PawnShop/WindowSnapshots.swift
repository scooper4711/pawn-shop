import AppKit
import PawnShopCore
import SwiftUI

/// For trying the app from a script: when `PAWN_SHOP_SNAPSHOT` names a path prefix, each window is drawn to
/// `<prefix>-<n>.png` a few seconds after launch. Drawing the app's own views needs no screen-recording access.
@MainActor
enum WindowSnapshots {
    static let delay: Duration = .seconds(6)

    static func scheduleIfRequested() {
        guard let prefix = ProcessInfo.processInfo.environment["PAWN_SHOP_SNAPSHOT"] else { return }
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            for (index, window) in NSApp.windows.filter(\.isVisible).enumerated() {
                save(window, to: URL(fileURLWithPath: "\(prefix)-\(index).png"))
            }
            await savePanels(prefix: prefix)
        }
    }

    /// The sidebar and inspector use glass that window drawing leaves blank, so they are also drawn alone.
    private static func savePanels(prefix: String) async {
        let library = LibraryModel.shared
        var sheet = PawnSheet()
        library.pawns.prefix(3).forEach { sheet.add($0.id, copies: 2) }
        let panels: [(String, AnyView)] = [
            ("library", AnyView(LibraryBrowser(sheet: .constant(sheet)))),
            ("inspector", AnyView(SheetInspector(sheet: .constant(sheet), selectedEntry: .constant(nil),
                                                 pageCount: 1))),
            ("review", AnyView(ReviewNamesView().frame(width: 520, height: 560))),
            ("custom", AnyView(CustomPawnPreview(image: sampleArt, name: "Nodocite Experimenter", size: .medium,
                                                 art: .constant(CustomArt(imageFile: "", scaling: .fit)))
                .frame(width: 200, height: 300)))
        ]
        for (name, panel) in panels {
            let window = NSWindow(contentRect: CGRect(x: -3000, y: 0, width: 540, height: 640), styleMask: [.titled],
                                  backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: panel.environment(library))
            window.orderFront(nil)
            try? await Task.sleep(for: .seconds(3))
            save(window, to: URL(fileURLWithPath: "\(prefix)-\(name).png"))
            window.orderOut(nil)
        }
    }

    private static var sampleArt: CGImage? {
        NSApp.applicationIconImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private static func save(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView, let layer = view.layer else { return }
        let scale = window.backingScaleFactor
        let size = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.scaleBy(x: scale, y: scale)
        if !view.isFlipped {
            layer.render(in: context)
        } else {
            context.translateBy(x: 0, y: view.bounds.height)
            context.scaleBy(x: 1, y: -1)
            layer.render(in: context)
        }
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
