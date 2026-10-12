import AppKit
import PawnShopCore
import SwiftUI

/// The item catalog: search, filters, and a grid of item cards to add to the sheet.
struct ItemBrowser: View {
    @Binding var sheet: PawnSheet
    /// The item shown large over the window; Space shows and hides it.
    @Binding var preview: String?
    @Environment(LibraryModel.self) private var library
    @State private var query = ItemQuery(kinds: [.consumable])
    @State private var selection: Set<String> = []
    @State private var copies = 1

    private let columns = [GridItem(.adaptive(minimum: 92, maximum: 130), spacing: 10, alignment: .top)]

    var body: some View {
        let results = library.searchItems(query)
        VStack(spacing: 0) {
            ItemFilterBar(query: $query)
            Divider()
            if library.catalog.items.isEmpty {
                MissingCatalogView()
            } else {
                grid(results)
            }
            Divider()
            addBar(resultCount: results.count)
        }
    }

    private func grid(_ results: [CatalogItem]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(results) { item in
                    ItemTile(card: library.card(for: item), isSelected: selection.contains(item.id))
                        .onTapGesture(count: 2) { sheet.add(.item(item.id), copies: copies) }
                        .onTapGesture { select(item.id) }
                        .contextMenu {
                            ForEach([1, 2, 4, 6], id: \.self) { count in
                                Button("Add \(count) to Sheet") { sheet.add(.item(item.id), copies: count) }
                            }
                        }
                        .help(item.traits.joined(separator: ", "))
                }
            }
            .padding(10)
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) { togglePreview() }
        .onKeyPress(.escape) {
            guard preview != nil else { return .ignored }
            preview = nil
            return .handled
        }
    }

    private func addBar(resultCount: Int) -> some View {
        HStack {
            Text("\(resultCount) item\(resultCount == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
            Spacer()
            Stepper("Copies: \(copies)", value: $copies, in: 1...50)
                .fixedSize()
            Button("Add to Sheet") {
                for item in library.catalog.items where selection.contains(item.id) {
                    sheet.add(.item(item.id), copies: copies)
                }
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(selection.isEmpty)
        }
        .padding(8)
    }

    private func togglePreview() -> KeyPress.Result {
        if preview != nil {
            preview = nil
        } else if selection.count == 1 {
            preview = selection.first
        } else {
            return .ignored
        }
        return .handled
    }

    /// A click selects one item; Command-click adds or removes it from the selection.
    private func select(_ id: String) {
        if NSEvent.modifierFlags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            selection = [id]
        }
    }
}

/// Search field and filter menu for items.
struct ItemFilterBar: View {
    /// Level ranges to filter by.
    static let levelRanges = [0...4, 5...9, 10...14, 15...20, 21...30]

    @Binding var query: ItemQuery

    var body: some View {
        HStack(spacing: 6) {
            TextField("Search names, traits and books", text: $query.text)
                .textFieldStyle(.roundedBorder)
            filterMenu
                .menuStyle(.borderlessButton)
                .fixedSize()
        }
        .padding(8)
    }

    private var filterMenu: some View {
        Menu {
            Section("Game") {
                ForEach(Game.allCases, id: \.self) { game in
                    Toggle(game.displayName, isOn: membership(of: game, in: \.games))
                }
            }
            Section("Kind") {
                ForEach(ItemKind.allCases, id: \.self) { kind in
                    Toggle(kind.displayName, isOn: membership(of: kind, in: \.kinds))
                }
            }
            Picker("Level", selection: $query.levels) {
                Text("Any Level").tag(ItemCatalog.levels)
                ForEach(Self.levelRanges, id: \.self) { range in
                    Text("Levels \(range.lowerBound)–\(range.upperBound)").tag(range)
                }
            }
            Divider()
            Button("Clear Filters") { query = ItemQuery(text: query.text) }
        } label: {
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle.fill"
                                         : "line.3.horizontal.decrease.circle")
        }
        .help("Filter by game, kind and level")
    }

    private var isFiltered: Bool {
        !query.games.isEmpty || !query.kinds.isEmpty || query.levels != ItemCatalog.levels
    }

    private func membership<Value: Hashable>(of value: Value,
                                             in keyPath: WritableKeyPath<ItemQuery, Set<Value>>) -> Binding<Bool> {
        Binding(get: { query[keyPath: keyPath].contains(value) },
                set: { isOn in
                    if isOn { query[keyPath: keyPath].insert(value) } else { query[keyPath: keyPath].remove(value) }
                })
    }
}

/// One item in the grid: its card, name and level.
struct ItemTile: View {
    let card: ItemCardContent
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            ItemCardThumbnail(card: card)
                .frame(height: 120)
            Text(card.item.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text("Level \(card.item.level) · \(card.item.game.displayName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(5)
        .background(isSelected ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}

/// An item's card, rendered in the background.
struct ItemCardThumbnail: View {
    let card: ItemCardContent
    /// Pixel height to render: a tile's, sharp on a Retina display, unless asked for larger, as by the preview.
    var pixelHeight = BackgroundRenderer.thumbnailHeight
    @Environment(LibraryModel.self) private var library
    @AppStorage(ItemCardPreferences.artOpacityKey) private var opacity = Double(ItemCard.defaultArtOpacity)
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 2).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                    .aspectRatio(ItemCard.size.width / ItemCard.size.height, contentMode: .fit)
            }
        }
        .task(id: "\(card.item.id)-\(card.artwork?.id.uuidString ?? "")-\(opacity)") {
            image = await library.backgroundRenderer?.cardImage(of: card, height: pixelHeight)
        }
    }
}

/// An item's card shown large over the window. Clicking outside it closes it.
struct ItemPreview: View {
    let card: ItemCardContent
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
            ItemCardThumbnail(card: card, pixelHeight: 1600)
                .frame(maxHeight: .infinity)
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(40)
        }
        .ignoresSafeArea()
    }
}

/// Shown when the app was built without the item list (`make items`).
struct MissingCatalogView: View {
    var body: some View {
        ContentUnavailableView("No Items", systemImage: "flask",
                               description: Text("This copy of Pawn Shop was built without the item list. Build "
                                                 + "it with \"make items\" before \"make app\"."))
            .frame(maxHeight: .infinity)
    }
}
