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
                ContentUnavailableView(
                    "Empty Sheet", systemImage: "doc",
                    description: Text("\(Self.addGesture) or drag pawns, items, or spells in the library to add them."))
            } else {
                pages(layout)
            }
        }
        // The whole pane, empty or not, takes the library's drags.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .focusable()
        .focusEffectDisabled()
        .deleteCommand {
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
        .background(Color.underPage)
    }

    private func currentLayout() -> SheetLayout {
        _ = library.pawns
        return library.exporter(for: sheet)?.layout() ?? SheetLayout(pages: [])
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
    /// Item cards' art opacity and backgrounds, so pages are drawn again when they change.
    @AppStorage(ItemCardPreferences.artOpacityKey) private var artOpacity = Double(ItemCard.defaultArtOpacity)
    @AppStorage(ItemCardPreferences.printsBackgroundsKey) private var printsBackgrounds = true
    @AppStorage(ItemCardPreferences.smallestTextSizeKey)
    private var smallestTextSize = Double(ItemCard.defaultSmallestTextSize)
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

    /// Changes whenever the page would look different: also when pictures its sheet lacked arrive, but not for
    /// pictures arriving for other pawns, which would draw every open page again at each batch.
    private var renderKey: String {
        let contents = Dictionary(uniqueKeysWithValues: sheet.entries.map { ($0.id, $0.content) })
        let strips = page.map { "\(contents[$0.entryID].map { "\($0)" } ?? "-")#\($0.card)@\($0.rect)\($0.sideways)" }
        return strips.joined(separator: ";") + "|\(sheet.settings)|\(library.pawns.count)|\(library.itemArt.count)"
            + "|\(artOpacity)|\(printsBackgrounds)|\(smallestTextSize)|\(library.missingPictureCount(of: sheet))"
    }

    private func render() async {
        guard let renderer = library.backgroundRenderer, let exporter = library.exporter(for: sheet) else { return }
        let drawing = PageDrawing(strips: page, contents: exporter.contents(of: page), settings: sheet.settings)
        // A drawing that was overtaken comes back empty: the page keeps what it shows until the next one is in.
        guard let drawn = await renderer.image(of: drawing, width: Int(Self.maximumWidth * 2)), !Task.isCancelled
        else { return }
        image = drawn
    }
}

extension SheetPreview {
    #if os(macOS)
    static let addGesture = "Double-click"
    #else
    static let addGesture = "Double-tap"
    #endif
}

extension Color {
    /// Behind the pages, as in a document app.
    static var underPage: Color {
        #if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}
