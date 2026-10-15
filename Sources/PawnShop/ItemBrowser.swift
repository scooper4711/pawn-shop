import AppKit
import PawnShopCore
import SwiftUI

/// What a catalog pane lists: items, or spells (R9.1).
enum CatalogPane: String {
    case items, spells

    var kinds: [ItemKind] { self == .spells ? ItemKind.spellKinds : ItemKind.itemKinds }
    /// What the pane shows before the user filters: consumables, or every spell.
    var initialKinds: Set<ItemKind> { self == .spells ? [] : [.consumable] }
    var noun: String { self == .spells ? "spell" : "item" }
}

/// The item or spell catalog: search, filters, and a grid of cards to add to the sheet.
struct ItemBrowser: View {
    @Binding var sheet: PawnSheet
    /// The item shown large over the window; Space shows and hides it.
    @Binding var preview: String?
    var pane = CatalogPane.items
    @Environment(LibraryModel.self) private var library
    @State private var query: ItemQuery
    @State private var selection: Set<String> = []
    @State private var copies = 1

    private let columns = [GridItem(.adaptive(minimum: 92, maximum: 130), spacing: 10, alignment: .top)]

    init(sheet: Binding<PawnSheet>, preview: Binding<String?>, pane: CatalogPane = .items) {
        _sheet = sheet
        _preview = preview
        self.pane = pane
        _query = State(initialValue: ItemQuery(kinds: pane.initialKinds))
    }

    /// The query limited to the pane's kinds when no kind is chosen.
    private var paneQuery: ItemQuery {
        var paneQuery = query
        if paneQuery.kinds.isEmpty { paneQuery.kinds = Set(pane.kinds) }
        return paneQuery
    }

    var body: some View {
        let results = library.searchItems(paneQuery)
        VStack(spacing: 0) {
            ItemFilterBar(query: $query, pane: pane)
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
            Text("\(resultCount) \(pane.noun)\(resultCount == 1 ? "" : "s")")
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

/// Search field and filter menu for items or spells.
struct ItemFilterBar: View {
    /// Level ranges to filter items by.
    static let levelRanges = [0...4, 5...9, 10...14, 15...20, 21...30]
    /// Rank ranges to filter spells by.
    static let rankRanges = [1...2, 3...4, 5...6, 7...8, 9...10]
    static let traditions = ["arcane", "divine", "occult", "primal"]

    @Binding var query: ItemQuery
    var pane = CatalogPane.items

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
                ForEach(pane.kinds, id: \.self) { kind in
                    Toggle(kind.displayName, isOn: membership(of: kind, in: \.kinds))
                }
            }
            if pane == .spells {
                Section("Tradition") {
                    ForEach(Self.traditions, id: \.self) { tradition in
                        Toggle(tradition.capitalized, isOn: membership(of: tradition, in: \.traditions))
                    }
                }
            }
            levelPicker
            Divider()
            Button("Clear Filters") { query = ItemQuery(text: query.text) }
        } label: {
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle.fill"
                                         : "line.3.horizontal.decrease.circle")
        }
        .help(pane == .spells ? "Filter by game, kind, rank and tradition" : "Filter by game, kind and level")
    }

    private var levelPicker: some View {
        let word = pane == .spells ? "Rank" : "Level"
        return Picker(word, selection: $query.levels) {
            Text("Any \(word)").tag(ItemCatalog.levels)
            ForEach(pane == .spells ? Self.rankRanges : Self.levelRanges, id: \.self) { range in
                Text("\(word)s \(range.lowerBound)–\(range.upperBound)").tag(range)
            }
        }
    }

    private var isFiltered: Bool {
        !query.games.isEmpty || !query.kinds.isEmpty || query.levels != ItemCatalog.levels || !query.traditions.isEmpty
    }

    private func membership<Value: Hashable>(of value: Value,
                                             in keyPath: WritableKeyPath<ItemQuery, Set<Value>>) -> Binding<Bool> {
        Binding(get: { query[keyPath: keyPath].contains(value) },
                set: { isOn in
                    if isOn { query[keyPath: keyPath].insert(value) } else { query[keyPath: keyPath].remove(value) }
                })
    }
}

/// One item or spell in the grid: its first card, name, level or rank, and how many cards it takes.
struct ItemTile: View {
    let card: ItemCardContent
    let isSelected: Bool
    @Environment(LibraryModel.self) private var library

    var body: some View {
        VStack(spacing: 3) {
            ItemCardThumbnail(card: card)
                .frame(height: 120)
            Text(card.item.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(5)
        .background(isSelected ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    /// "Spell 3 · 2 cards · Pathfinder".
    private var caption: String {
        let item = card.item
        let kind = item.kind.isSpell ? item.kind.cardLabel.capitalized : "Level"
        let cards = library.cardCount(for: item)
        return ["\(kind) \(item.level)", cards > 1 ? "\(cards) cards" : nil, item.game.displayName]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

/// An item's card, rendered in the background.
struct ItemCardThumbnail: View {
    let card: ItemCardContent
    /// Pixel height to render: a tile's, sharp on a Retina display, unless asked for larger, as by the preview.
    var pixelHeight = BackgroundRenderer.thumbnailHeight
    @Environment(LibraryModel.self) private var library
    @AppStorage(ItemCardPreferences.artOpacityKey) private var opacity = Double(ItemCard.defaultArtOpacity)
    @AppStorage(ItemCardPreferences.printsBackgroundsKey) private var printsBackgrounds = true
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
        .task(id: "\(card.item.id)-\(card.card)-\(card.artwork?.id.uuidString ?? "")-\(opacity)-\(printsBackgrounds)") {
            image = await library.backgroundRenderer?.cardImage(of: card, height: pixelHeight)
        }
    }
}

/// An item's cards shown large over the window, side by side. Clicking outside them closes them.
struct ItemPreview: View {
    let card: ItemCardContent
    let close: () -> Void
    @Environment(LibraryModel.self) private var library

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
            HStack(spacing: 16) {
                ForEach(0..<library.cardCount(for: card.item), id: \.self) { index in
                    ItemCardThumbnail(card: ItemCardContent(item: card.item, artwork: card.artwork, card: index),
                                      pixelHeight: 1600)
                }
            }
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
