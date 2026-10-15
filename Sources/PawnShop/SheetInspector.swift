import PawnShopCore
import SwiftUI

/// The sheet's pawns with their copies, and how the sheet is cut and folded.
struct SheetInspector: View {
    @Binding var sheet: PawnSheet
    @Binding var selectedEntry: UUID?
    let pageCount: Int
    @Environment(LibraryModel.self) private var library

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedEntry) {
                Section("Pawns and Items") {
                    ForEach($sheet.entries) { $entry in
                        SheetEntryRow(entry: $entry) { sheet.remove(entry.id) }
                            .tag(entry.id)
                    }
                }
            }
            Divider()
            CutSettingsForm(settings: $sheet.settings)
            HStack {
                Text(paperDescription).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Page Setup…") { SheetOutput.runPageSetup(for: &sheet) }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            Divider()
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }

    private var paperDescription: String {
        let size = sheet.settings.paper.paperSize
        return String(format: "Paper %.4g × %.4g in", size.width / pointsPerInch, size.height / pointsPerInch)
    }

    private var summary: String {
        let copies = sheet.entries.filter { $0.itemID != nil }.reduce(0) { $0 + $1.count }
        let pawns = sheet.copyCount - copies
        // Every card of each copy's set (R8.3.1).
        let cards = sheet.entries.reduce(0) { total, entry in
            let item = entry.itemID.flatMap(library.catalog.item(id:))
            return total + (item.map { library.cardCount(for: $0) * entry.count } ?? 0)
        }
        var parts = ["\(pawns) pawn\(pawns == 1 ? "" : "s")"]
        if cards > 0 { parts.append("\(cards) card\(cards == 1 ? "" : "s")") }
        return "\(parts.joined(separator: " and ")) on \(pageCount) page\(pageCount == 1 ? "" : "s")"
    }
}

/// A pawn or item card on the sheet, with its copies.
struct SheetEntryRow: View {
    @Binding var entry: SheetEntry
    let remove: () -> Void
    @Environment(LibraryModel.self) private var library

    var body: some View {
        HStack {
            label
            Spacer()
            Stepper("\(entry.count)", value: $entry.count, in: 1...99)
                .fixedSize()
            Button(action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .help("Remove from the sheet")
        }
    }

    @ViewBuilder private var label: some View {
        switch entry.content {
        case .pawn(let pawnID):
            let pawn = library.pawn(id: pawnID)
            if let pawn {
                PawnThumbnail(pawn: pawn).frame(width: 28, height: 40)
            }
            VStack(alignment: .leading) {
                Text(pawn?.name ?? "Missing pawn").lineLimit(1)
                Text(pawn?.size.displayName ?? "").font(.caption).foregroundStyle(.secondary)
            }
        case .item(let itemID):
            let item = library.catalog.item(id: itemID)
            if let item {
                ItemCardThumbnail(card: library.card(for: item)).frame(width: 28, height: 40)
            }
            VStack(alignment: .leading) {
                Text(item?.name ?? "Missing item").lineLimit(1)
                Text(item.map(caption) ?? "").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// "Spell card · rank 2 · 2 cards a copy" or "Item card · level 1".
    private func caption(_ item: CatalogItem) -> String {
        let cards = library.cardCount(for: item)
        return [item.kind.isSpell ? "Spell card · rank \(item.level)" : "Item card · level \(item.level)",
                cards > 1 ? "\(cards) cards a copy" : nil].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Cut style, fold line and room for a base.
struct CutSettingsForm: View {
    @Binding var settings: SheetSettings

    var body: some View {
        Form {
            Picker("Cut lines", selection: sharedLines) {
                Text("Shared").tag(true)
                Text("Gaps").tag(false)
            }
            .pickerStyle(.segmented)
            if case .gaps(let points) = settings.cutStyle {
                Stepper(String(format: "Gap: %.2f in", points / pointsPerInch),
                        value: gapInches, in: 0.05...0.5, step: 0.05)
            }
            Toggle("Show fold line", isOn: $settings.showsFoldLine)
            Toggle("Leave room for a base", isOn: $settings.leavesRoomForBase)
                .help("Adds blank room below each face's foot, so the base's slot covers it instead of the name. "
                      + "The pawn's art stays the same size; the strip gets taller.")
            if settings.leavesRoomForBase {
                Stepper(String(format: "Room: %.1f mm", settings.baseRoom.millimeters),
                        value: baseRoomMillimeters, in: 0.5...20, step: 0.5)
            }
        }
        .padding(8)
    }

    private var baseRoomMillimeters: Binding<Double> {
        Binding(get: { Double(settings.baseRoom.millimeters) },
                set: { settings.baseRoom = .millimeters(CGFloat($0)) })
    }

    private var sharedLines: Binding<Bool> {
        Binding(get: { settings.cutStyle == .sharedLines },
                set: { settings.cutStyle = $0 ? .sharedLines : .gaps(CutStyle.defaultGap) })
    }

    private var gapInches: Binding<Double> {
        Binding(get: {
            if case .gaps(let points) = settings.cutStyle { return Double(points / pointsPerInch) }
            return 0
        }, set: { settings.cutStyle = .gaps(CGFloat($0) * pointsPerInch) })
    }

}
