import AppKit
import PawnShopCore
import SwiftUI

/// The library: search, filters, and a grid of pawns to add to the sheet.
struct LibraryBrowser: View {
    @Binding var sheet: PawnSheet
    /// The pawn shown large over the window; Space shows and hides it, the arrow keys move it.
    @Binding var preview: UUID?
    /// Opens the review of pawns needing a name.
    var reviewNames: () -> Void = { /* no review unless the window provides one */ }
    @Environment(LibraryModel.self) private var library
    @State private var query = PawnQuery()
    @State private var selection: Set<UUID> = []
    @State private var copies = 1
    @State private var renaming: Pawn?
    @State private var editingKeywords: Pawn?
    /// The pawn the arrow keys move from: the one last clicked or arrowed to.
    @State private var cursor: UUID?
    @State private var columnCount = 1
    @FocusState private var gridFocused: Bool

    private static let tileMinimumWidth: CGFloat = 92
    private static let tileSpacing: CGFloat = 10
    private static let gridPadding: CGFloat = 10
    private let columns = [GridItem(.adaptive(minimum: tileMinimumWidth, maximum: 130), spacing: tileSpacing,
                                    alignment: .top)]

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
        .sheet(item: $editingKeywords) { pawn in
            EditKeywordsView(pawn: pawn) { library.correctTags($0, of: pawn.id) }
        }
    }

    private func grid(_ results: [Pawn]) -> some View {
        ScrollViewReader { scroller in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(results) { pawn in
                        PawnTile(pawn: pawn, productTitle: library.shortSourceTitle(of: pawn),
                                 isSelected: selection.contains(pawn.id))
                            .onTapGesture(count: 2) { sheet.add(pawn.id, copies: copies) }
                            .onTapGesture { select(pawn.id) }
                            .contextMenu { menu(for: pawn) }
                            .help(help(for: pawn))
                            .onAppear { PawnTaggingModel.shared.show(pawn.id) }
                            .onDisappear { PawnTaggingModel.shared.hide(pawn.id) }
                    }
                }
                .padding(Self.gridPadding)
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                columnCount = GridNavigation.columns(fitting: width - 2 * Self.gridPadding,
                                                     minimum: Self.tileMinimumWidth, spacing: Self.tileSpacing)
            }
            .focusable()
            .focusEffectDisabled()
            .focused($gridFocused)
            .onKeyPress(.space) { togglePreview() }
            .onKeyPress(.escape) { closePreview() }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                guard let move = Self.gridMove(for: press.key) else { return .ignored }
                return step(move, in: results, scroller: scroller)
            }
        }
    }

    private func togglePreview() -> KeyPress.Result {
        guard preview == nil else { return closePreview() }
        guard let cursor, selection.contains(cursor) else { return .ignored }
        preview = cursor
        return .handled
    }

    private func closePreview() -> KeyPress.Result {
        guard preview != nil else { return .ignored }
        preview = nil
        return .handled
    }

    /// Selects the pawn `move` lands on, keeping it in view and in the preview when one is open.
    private func step(_ move: GridMove, in results: [Pawn], scroller: ScrollViewProxy) -> KeyPress.Result {
        guard !results.isEmpty else { return .ignored }
        let current = results.firstIndex { $0.id == cursor } ?? 0
        let target = results[GridNavigation.index(after: move, from: current, count: results.count,
                                                  columns: columnCount)].id
        selection = [target]
        cursor = target
        if preview != nil { preview = target }
        scroller.scrollTo(target)
        return .handled
    }

    private static func gridMove(for key: KeyEquivalent) -> GridMove? {
        switch key {
        case .leftArrow: .left
        case .rightArrow: .right
        case .upArrow: .up
        case .downArrow: .down
        default: nil
        }
    }

    private func addBar(resultCount: Int) -> some View {
        HStack {
            Text("\(resultCount) pawn\(resultCount == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
            TaggingStatus()
            Spacer()
            Stepper("Copies: \(copies)", value: $copies, in: 1...50)
                .fixedSize()
            Button("Add to Sheet", action: addSelection)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(selection.isEmpty)
        }
        .padding(8)
    }

    /// The pawn's products, traits and tags, shown on hover.
    private func help(for pawn: Pawn) -> String {
        let products = library.sourceTitles(of: pawn).joined(separator: "\n")
        let words = [pawn.traits, pawn.tags].filter { !$0.isEmpty }.map { $0.joined(separator: ", ") }
        return ([products] + words).joined(separator: "\n\n")
    }

    @ViewBuilder
    private func menu(for pawn: Pawn) -> some View {
        ForEach([1, 2, 4, 6], id: \.self) { count in
            Button("Add \(count) to Sheet") { sheet.add(pawn.id, copies: count) }
        }
        Divider()
        Button("Rename…") { renaming = pawn }
        Button("Edit Keywords…") { editingKeywords = pawn }
        Button("Remove from Library", role: .destructive) {
            library.remove(selection.contains(pawn.id) ? selection : [pawn.id])
            selection.subtract([pawn.id])
        }
    }

    /// A click selects one pawn; Command-click adds or removes it from the selection.
    private func select(_ id: UUID) {
        cursor = id
        gridFocused = true
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

/// A spinner while pawns are being tagged, or a warning when tagging stopped.
struct TaggingStatus: View {
    private let tagging = PawnTaggingModel.shared

    var body: some View {
        if let progress = tagging.progress {
            ProgressView()
                .controlSize(.small)
                .help("Tagging pawns with \(tagging.tagger.model): \(progress.done) of \(progress.total)")
        } else if let problem = tagging.problem {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .help(problem + "\nLibrary › Tag New Pawns tries again.")
        }
    }
}

/// Search field and filter menus.
struct LibraryFilterBar: View {
    @Binding var query: PawnQuery
    let sources: [PawnSource]

    var body: some View {
        HStack(spacing: 6) {
            TextField("Search names and tags", text: $query.text)
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
