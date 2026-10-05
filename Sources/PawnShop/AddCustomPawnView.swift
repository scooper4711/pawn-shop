import AppKit
import PawnShopCore
import SwiftUI
import UniformTypeIdentifiers

/// Makes a pawn from the user's own art: choose, drop or paste an image (such as one copied from Pluck), name
/// it, pick its size, and drag the preview to place the art in the outline.
struct AddCustomPawnView: View {
    /// Called with the new pawn, which is already in the library.
    let added: (Pawn) -> Void
    @Environment(LibraryModel.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var image: CGImage?
    @State private var name = ""
    @State private var size = PawnSize.medium
    @State private var focus = CGPoint(x: 0.5, y: 0.5)
    @State private var showsName = true

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            CustomPawnPreview(image: image, name: name, size: size, focus: $focus, showsName: showsName)
                .frame(width: 200, height: 300)
                .dropDestination(for: URL.self) { urls, _ in load(urls.first) }
            Form {
                HStack {
                    Button("Choose Image…", action: chooseImage)
                    Button("Paste Image", action: paste)
                        .disabled(!Self.pasteboardHasImage)
                }
                TextField("Name", text: $name)
                Picker("Size", selection: $size) {
                    ForEach(PawnSize.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Print the name", isOn: $showsName)
                Text("Drop or paste (⌘V) an image, then drag the art in the preview to place it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 260)
        }
        .padding()
        .onPasteCommand(of: [.image, .fileURL]) { _ in paste() }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add Pawn", action: add).disabled(image == nil)
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK else { return }
        _ = load(panel.url)
    }

    static var pasteboardHasImage: Bool {
        NSImage.canInit(with: .general)
    }

    /// Takes the image on the clipboard: image data (as Pluck copies it) or a copied image file.
    private func paste() {
        let pasteboard = NSPasteboard.general
        if let url = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL])?.first, load(url) { return }
        guard let pasted = NSImage(pasteboard: pasteboard),
              let cgImage = pasted.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }
        image = cgImage
        focus = CGPoint(x: 0.5, y: 0.5)
    }

    @discardableResult
    private func load(_ url: URL?) -> Bool {
        guard let url, let loaded = try? PawnLibrary.image(at: url) else { return false }
        image = loaded
        focus = CGPoint(x: 0.5, y: 0.5)
        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
        return true
    }

    private func add() {
        guard let image else { return }
        let new = NewCustomPawn(image: image, name: name, size: size, focus: focus, showsName: showsName)
        if let pawn = library.addCustomPawn(new) { added(pawn) }
        dismiss()
    }
}

/// The pawn's front as it will print, with the art draggable inside the outline.
struct CustomPawnPreview: View {
    let image: CGImage?
    let name: String
    let size: PawnSize
    @Binding var focus: CGPoint
    let showsName: Bool
    @State private var dragStart: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            let outline = fitted(size.outlineSize, in: geometry.size)
            ZStack(alignment: .bottom) {
                Color.white
                if let image { art(image, in: outline) } else { Text("No image").foregroundStyle(.secondary) }
                if showsName {
                    Text(name.uppercased())
                        .font(.system(size: max(6, outline.height * 0.06), weight: .bold))
                        .foregroundStyle(.black)
                        // Like the printed pawn: a second line before smaller type.
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, outline.width * 0.04)
                        .frame(width: outline.width)
                        .frame(minHeight: outline.height * 0.13)
                        .background(.white.opacity(0.85))
                }
            }
            .frame(width: outline.width, height: outline.height)
            .clipped()
            .border(.gray.opacity(0.6), width: 0.5)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func art(_ image: CGImage, in outline: CGSize) -> some View {
        let imageSize = CGSize(width: image.width, height: image.height)
        let fill = PawnRenderer.fillRect(for: imageSize, in: CGRect(origin: .zero, size: outline), focus: focus)
        return Image(decorative: image, scale: 1)
            .resizable()
            .frame(width: fill.width, height: fill.height)
            // The renderer measures from the bottom; SwiftUI from the top.
            .position(x: fill.midX, y: outline.height - fill.midY)
            .frame(width: outline.width, height: outline.height)
            .gesture(drag(overflow: CGSize(width: fill.width - outline.width, height: fill.height - outline.height)))
    }

    /// Dragging moves the art with the pointer, within the image's overflow.
    private func drag(overflow: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStart ?? focus
                dragStart = start
                let deltaX = overflow.width > 0 ? value.translation.width / overflow.width : 0
                let deltaY = overflow.height > 0 ? value.translation.height / overflow.height : 0
                focus = CGPoint(x: min(max(start.x - deltaX, 0), 1), y: min(max(start.y + deltaY, 0), 1))
            }
            .onEnded { _ in dragStart = nil }
    }

    private func fitted(_ size: CGSize, in bounds: CGSize) -> CGSize {
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
