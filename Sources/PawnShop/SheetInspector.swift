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
                Section("Pawns") {
                    ForEach($sheet.entries) { $entry in
                        SheetEntryRow(entry: $entry, pawn: library.pawn(id: entry.pawnID)) {
                            sheet.remove(entry.id)
                        }
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
        let copies = sheet.copyCount
        return "\(copies) pawn\(copies == 1 ? "" : "s") on \(pageCount) page\(pageCount == 1 ? "" : "s")"
    }
}

struct SheetEntryRow: View {
    @Binding var entry: SheetEntry
    let pawn: Pawn?
    let remove: () -> Void

    var body: some View {
        HStack {
            if let pawn {
                PawnThumbnail(pawn: pawn).frame(width: 28, height: 40)
            }
            VStack(alignment: .leading) {
                Text(pawn?.name ?? "Missing pawn").lineLimit(1)
                Text(pawn?.size.displayName ?? "").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Stepper("\(entry.count)", value: $entry.count, in: 1...99)
                .fixedSize()
            Button(action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .help("Remove from the sheet")
        }
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
