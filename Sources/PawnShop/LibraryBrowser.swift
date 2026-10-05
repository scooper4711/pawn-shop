import AppKit
import PawnShopCore
import SwiftUI

/// The library: search, filters, and a grid of pawns to add to the sheet.
struct LibraryBrowser: View {
    @Binding var sheet: PawnSheet
    /// Opens the review of pawns needing a name.
    var reviewNames: () -> Void = {}
    @Environment(LibraryModel.self) private var library
    @State private var query = PawnQuery()
    @State private var selection: Set<UUID> = []
    @State private var copies = 1
    @State private var renaming: Pawn?

    private let columns = [GridItem(.adaptive(minimum: 92, maximum: 130), spacing: 10, alignment: .top)]

    var body: some View {
        let results = library.pawns.isEmpty ? [] : library.search(query)
        VStack(spacing: 0) {
            LibraryFilterBar(query: $query, sources: library.sources)
            Divider()
            if !library.pawnsNeedingNames.isEmpty {
                NeedsNamesBanner(count: library.pawnsNeedingNames.count, review: reviewNames)
                Divider()
            }
            if library.pawns.isEmpty {
                EmptyLibraryView()
            } else {
                grid(results)
            }
            Divider()
            addBar(resultCount: results.count)
        }
        .sheet(item: $renaming) { pawn in
            RenamePawnView(pawn: pawn) { library.rename(pawn.id, to: $0) }
        }
    }

    private func grid(_ results: [Pawn]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(results) { pawn in
                    PawnTile(pawn: pawn, productTitle: library.shortSourceTitle(of: pawn),
                             isSelected: selection.contains(pawn.id))
                        .onTapGesture(count: 2) { sheet.add(pawn.id, copies: copies) }
                        .onTapGesture { select(pawn.id) }
                        .contextMenu { menu(for: pawn) }
                        .help(library.sourceTitles(of: pawn).joined(separator: "\n"))
                }
            }
            .padding(10)
        }
    }

    private func addBar(resultCount: Int) -> some View {
        HStack {
            Text("\(resultCount) pawn\(resultCount == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
            Spacer()
            Stepper("Copies: \(copies)", value: $copies, in: 1...50)
                .fixedSize()
            Button("Add to Sheet", action: addSelection)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(selection.isEmpty)
        }
        .padding(8)
    }

    @ViewBuilder
    private func menu(for pawn: Pawn) -> some View {
        ForEach([1, 2, 4, 6], id: \.self) { count in
            Button("Add \(count) to Sheet") { sheet.add(pawn.id, copies: count) }
        }
        Divider()
        Button("Rename…") { renaming = pawn }
        Button("Remove from Library", role: .destructive) {
            library.remove(selection.contains(pawn.id) ? selection : [pawn.id])
            selection.subtract([pawn.id])
        }
    }

    /// A click selects one pawn; Command-click adds or removes it from the selection.
    private func select(_ id: UUID) {
        if NSEvent.modifierFlags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            selection = [id]
        }
    }

    private func addSelection() {
        for pawn in library.pawns where selection.contains(pawn.id) {
            sheet.add(pawn.id, copies: copies)
        }
    }
}

/// Search field and filter menus.
struct LibraryFilterBar: View {
    @Binding var query: PawnQuery
    let sources: [PawnSource]

    var body: some View {
        HStack(spacing: 6) {
            TextField("Search pawns", text: $query.text)
                .textFieldStyle(.roundedBorder)
            filterMenu
                .menuStyle(.borderlessButton)
                .fixedSize()
        }
        .padding(8)
    }

    private var filterMenu: some View {
        Menu {
            Section("Size") {
                ForEach(PawnSize.allCases, id: \.self) { size in
                    Toggle(size.displayName, isOn: membership(of: size, in: \.sizes))
                }
            }
            Section("Game") {
                ForEach(Game.allCases, id: \.self) { game in
                    Toggle(game.displayName, isOn: membership(of: game, in: \.games))
                }
            }
            Menu("Product") {
                ForEach(sources) { source in
                    Toggle(source.title, isOn: membership(of: source.id, in: \.sourceIDs))
                }
            }
            Toggle("Custom Pawns Only", isOn: Binding(get: { query.custom == true },
                                                      set: { query.custom = $0 ? true : nil }))
            Toggle("Needs a Name", isOn: $query.needingNamesOnly)
            Divider()
            Button("Clear Filters") { query = PawnQuery(text: query.text) }
        } label: {
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle.fill"
                                         : "line.3.horizontal.decrease.circle")
        }
        .help("Filter by size, game and product")
    }

    private var isFiltered: Bool {
        !query.sizes.isEmpty || !query.games.isEmpty || !query.sourceIDs.isEmpty || query.custom != nil
            || query.needingNamesOnly
    }

    private func membership<Value: Hashable>(of value: Value,
                                             in keyPath: WritableKeyPath<PawnQuery, Set<Value>>) -> Binding<Bool> {
        Binding(get: { query[keyPath: keyPath].contains(value) },
                set: { isOn in
                    if isOn { query[keyPath: keyPath].insert(value) } else { query[keyPath: keyPath].remove(value) }
                })
    }
}

/// One pawn in the grid: its front, name, size and product.
struct PawnTile: View {
    let pawn: Pawn
    let productTitle: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            PawnThumbnail(pawn: pawn)
                .frame(height: 96)
            Text(pawn.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text("\(pawn.size.displayName) · \(productTitle)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(5)
        .background(isSelected ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}

/// A pawn's face, rendered in the background.
struct PawnThumbnail: View {
    let pawn: Pawn
    var side: PawnSide = .front
    /// Pixel height to render; larger for big previews.
    var pixelHeight = BackgroundRenderer.thumbnailHeight
    @Environment(LibraryModel.self) private var library
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 2).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
            }
        }
        .task(id: pawn) {
            let renderer = library.backgroundRenderer
            image = renderer?.cachedThumbnail(of: pawn, side: side, height: pixelHeight)
            if image == nil { image = await renderer?.thumbnail(of: pawn, side: side, height: pixelHeight) }
        }
    }
}

struct EmptyLibraryView: View {
    @Environment(LibraryModel.self) private var library

    var body: some View {
        ContentUnavailableView {
            Label("No Pawns Yet", systemImage: "person.crop.rectangle.stack")
        } description: {
            Text("Import Paizo pawn PDFs to build your library.")
        } actions: {
            Button("Import from Scrollkeeper") { library.importFromScrollkeeper() }
            Button("Import PDF…") { library.chooseAndImportPDFs() }
        }
        .frame(maxHeight: .infinity)
    }
}

/// Asks for a pawn's new name.
struct RenamePawnView: View {
    let pawn: Pawn
    let rename: (String) -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("Name", text: $name)
        }
        .padding()
        .frame(width: 320)
        .onAppear { name = pawn.name }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Rename") {
                    rename(name)
                    dismiss()
                }
            }
        }
    }
}
