import ArtExtraction
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
    /// Placement, scaling and name choices; the image file is set when the pawn is saved.
    @State private var art = CustomArt(imageFile: "")

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            CustomPawnPreview(image: image, name: name, size: size, art: $art)
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
                Picker("Picture", selection: $art.scaling) {
                    ForEach(ArtScaling.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: art.scaling) { art.focus = CGPoint(x: 0.5, y: 0.5) }
                Toggle("Print the name", isOn: $art.showsName)
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
        art.focus = CGPoint(x: 0.5, y: 0.5)
    }

    @discardableResult
    private func load(_ url: URL?) -> Bool {
        guard let url, let loaded = try? PawnLibrary.image(at: url) else { return false }
        image = loaded
        art.focus = CGPoint(x: 0.5, y: 0.5)
        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
        return true
    }

    private func add() {
        guard let image else { return }
        var new = NewCustomPawn(image: image, name: name, size: size, focus: art.focus, showsName: art.showsName)
        new.scaling = art.scaling
        if let pawn = library.addCustomPawn(new) { added(pawn) }
        dismiss()
    }
}

/// The pawn's front as it will print, with the art draggable inside the outline. It uses the renderer's
/// placement and name layout, so it matches the printed pawn.
struct CustomPawnPreview: View {
    let image: CGImage?
    let name: String
    let size: PawnSize
    @Binding var art: CustomArt
    @State private var dragStart: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            let outline = CGRect(origin: .zero, size: fitted(size.outlineSize, in: geometry.size))
            ZStack(alignment: .bottom) {
                Color.white
                if let image { picture(image, in: outline) } else { Text("No image").foregroundStyle(.secondary) }
                if art.showsName { nameBand(in: outline) }
            }
            .frame(width: outline.width, height: outline.height)
            .clipped()
            .border(.gray.opacity(0.6), width: 0.5)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func nameBand(in outline: CGRect) -> some View {
        let layout = PawnRenderer.nameLayout(for: name, in: outline)
        return Text(layout.lines.joined(separator: "\n"))
            .font(.system(size: layout.fontSize, weight: .bold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .frame(width: outline.width, height: PawnRenderer.nameBandHeight(for: name, in: outline))
            .background(.white.opacity(0.85))
    }

    private func picture(_ image: CGImage, in outline: CGRect) -> some View {
        let area = PawnRenderer.artArea(for: art, named: name, in: outline)
        let placed = PawnRenderer.artRect(for: CGSize(width: image.width, height: image.height), in: area,
                                          focus: art.focus, scaling: art.scaling)
        return Image(decorative: image, scale: 1)
            .resizable()
            .frame(width: placed.width, height: placed.height)
            // The renderer measures from the bottom; SwiftUI from the top.
            .position(x: placed.midX, y: outline.height - placed.midY)
            .frame(width: outline.width, height: outline.height)
            .contentShape(Rectangle())
            .gesture(drag(room: CGSize(width: placed.width - area.width, height: placed.height - area.height)))
    }

    /// Dragging moves the art with the pointer, within its room to move: the overflow when filling (positive)
    /// or the free space when fitting (negative).
    private func drag(room: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStart ?? art.focus
                dragStart = start
                let deltaX = abs(room.width) > 0.5 ? value.translation.width / room.width : 0
                let deltaY = abs(room.height) > 0.5 ? value.translation.height / room.height : 0
                art.focus = CGPoint(x: min(max(start.x - deltaX, 0), 1), y: min(max(start.y + deltaY, 0), 1))
            }
            .onEnded { _ in dragStart = nil }
    }

    private func fitted(_ size: CGSize, in bounds: CGSize) -> CGSize {
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
