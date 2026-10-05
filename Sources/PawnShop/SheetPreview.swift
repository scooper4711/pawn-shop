import PawnShopCore
import SwiftUI

/// The sheet's pages as they will print. Clicking a strip selects its pawn; Delete removes one copy.
struct SheetPreview: View {
    @Binding var sheet: PawnSheet
    @Binding var selectedEntry: UUID?
    @Environment(LibraryModel.self) private var library

    var body: some View {
        let layout = currentLayout()
        Group {
            if sheet.entries.isEmpty {
                ContentUnavailableView("Empty Sheet", systemImage: "doc",
                                       description: Text("Double-click pawns in the library to add them."))
            } else {
                pages(layout)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onDeleteCommand {
            if let selectedEntry { sheet.removeCopy(of: selectedEntry) }
        }
    }

    private func pages(_ layout: SheetLayout) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(Array(layout.pages.enumerated()), id: \.offset) { index, page in
                    PageView(page: page, sheet: sheet, selectedEntry: selectedEntry) { point in
                        selectedEntry = layout.strip(at: point, onPage: index)?.entryID
                    }
                    Text("Page \(index + 1) of \(layout.pages.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func currentLayout() -> SheetLayout {
        guard let pawnLibrary = library.library, let renderer = library.renderer else { return SheetLayout(pages: []) }
        _ = library.pawns
        return SheetExporter(sheet: sheet, library: pawnLibrary, renderer: renderer).layout()
    }
}

/// One page: rendered in the background, with the selected pawn's strips outlined.
struct PageView: View {
    static let maximumWidth: CGFloat = 640

    let page: [PlacedStrip]
    let sheet: PawnSheet
    let selectedEntry: UUID?
    let select: (CGPoint) -> Void
    @Environment(LibraryModel.self) private var library
    @State private var image: CGImage?

    private var paper: PaperSetup { sheet.settings.paper }

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / paper.paperSize.width
            ZStack(alignment: .topLeading) {
                Color.white
                if let image {
                    Image(decorative: image, scale: 1).resizable()
                }
                ForEach(Array(page.enumerated()), id: \.offset) { _, strip in
                    if strip.entryID == selectedEntry {
                        Rectangle()
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                            .frame(width: strip.rect.width * scale, height: strip.rect.height * scale)
                            .offset(x: strip.rect.minX * scale, y: (paper.paperSize.height - strip.rect.maxY) * scale)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                select(CGPoint(x: location.x / scale, y: paper.paperSize.height - location.y / scale))
            }
        }
        .aspectRatio(paper.paperSize.width / paper.paperSize.height, contentMode: .fit)
        .frame(maxWidth: Self.maximumWidth)
        .shadow(radius: 3)
        .task(id: renderKey) { await render() }
    }

    /// Changes whenever the page would look different.
    private var renderKey: String {
        let pawnIDs = Dictionary(uniqueKeysWithValues: sheet.entries.map { ($0.id, $0.pawnID) })
        let strips = page.map { "\(pawnIDs[$0.entryID].map(\.uuidString) ?? "-")@\($0.rect)\($0.sideways)" }
        return strips.joined(separator: ";") + "|\(sheet.settings)|\(library.pawns.count)"
    }

    private func render() async {
        guard let renderer = library.backgroundRenderer else { return }
        let pawnIDs = Dictionary(uniqueKeysWithValues: sheet.entries.map { ($0.id, $0.pawnID) })
        let pawns = page.map { pawnIDs[$0.entryID].flatMap(library.pawn(id:)) }
        image = await renderer.image(of: PageDrawing(strips: page, pawns: pawns, settings: sheet.settings),
                                  width: Int(Self.maximumWidth * 2))
    }
}
