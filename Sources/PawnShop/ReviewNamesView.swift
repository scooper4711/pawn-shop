import PawnShopCore
import SwiftUI

/// Steps through the pawns waiting for a name. Each name is saved as it is entered, so the review can be
/// closed at any time and picks up with the pawns still unnamed when opened again.
struct ReviewNamesView: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    /// Pawns passed over in this review; they come round again next time.
    @State private var skipped: Set<UUID> = []
    @FocusState private var nameFocused: Bool

    private var remaining: [Pawn] { library.pawnsNeedingNames }
    private var current: Pawn? { remaining.first { !skipped.contains($0.id) } }

    var body: some View {
        VStack(spacing: 14) {
            if let pawn = current {
                review(pawn)
            } else if remaining.isEmpty {
                ContentUnavailableView("Every Pawn Has a Name", systemImage: "checkmark.circle")
            } else {
                ContentUnavailableView {
                    Label("\(remaining.count) Skipped", systemImage: "forward")
                } actions: {
                    Button("Review Skipped Pawns") { skipped = [] }
                }
            }
        }
        .padding()
        .frame(width: 520, height: 560)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
        }
    }

    private func review(_ pawn: Pawn) -> some View {
        VStack(spacing: 14) {
            Text("\(remaining.count) pawn\(remaining.count == 1 ? "" : "s") to name")
                .font(.headline)
            HStack(spacing: 16) {
                PawnThumbnail(pawn: pawn, pixelHeight: 600).frame(height: 300)
                PawnThumbnail(pawn: pawn, side: .back, pixelHeight: 600).frame(height: 300)
            }
            Text("\(pawn.size.displayName) · \(library.sourceTitles(of: pawn).joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !pawn.tags.isEmpty {
                Text(pawn.tags.joined(separator: ", "))
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit { save(pawn) }
            HStack {
                Button("Skip") { skip(pawn) }
                Spacer()
                Button("Save and Next") { save(pawn) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            name = pawn.suggestedName
            nameFocused = true
        }
        // A suggestion arriving while the pawn is on screen fills the field, unless something is typed already.
        .onChange(of: pawn.suggestedName) { _, suggestion in
            if name.isEmpty { name = suggestion }
        }
        .id(pawn.id)
    }

    private func save(_ pawn: Pawn) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        library.rename(pawn.id, to: name)
        name = ""
        nameFocused = true
    }

    private func skip(_ pawn: Pawn) {
        skipped.insert(pawn.id)
        name = ""
    }
}

/// Above the library grid while pawns are waiting for a name.
struct NeedsNamesBanner: View {
    let count: Int
    let review: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "questionmark.square.dashed")
            Text("\(count) pawn\(count == 1 ? "" : "s") need\(count == 1 ? "s" : "") a name")
            Spacer()
            Button("Review…", action: review)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.yellow.opacity(0.15))
    }
}
