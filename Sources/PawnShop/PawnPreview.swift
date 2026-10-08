import PawnShopCore
import SwiftUI

/// A pawn's front and back shown large over the window, like Quick Look. Clicking outside it closes it.
struct PawnPreview: View {
    /// Tall enough to stay sharp at the size the preview reaches on a large display.
    static let pixelHeight = 1200

    let pawn: Pawn
    let close: () -> Void
    @Environment(LibraryModel.self) private var library
    @State private var editingKeywords = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
            VStack(spacing: 10) {
                HStack(spacing: 24) {
                    PawnThumbnail(pawn: pawn, pixelHeight: Self.pixelHeight)
                    PawnThumbnail(pawn: pawn, side: .back, pixelHeight: Self.pixelHeight)
                }
                .frame(maxHeight: .infinity)
                Text(pawn.name).font(.title2.weight(.semibold))
                Text("\(pawn.size.displayName) · \(library.sourceTitles(of: pawn).joined(separator: ", "))")
                    .foregroundStyle(.secondary)
                HStack {
                    if !pawn.tags.isEmpty {
                        Text(pawn.tags.joined(separator: ", ")).font(.callout).foregroundStyle(.secondary)
                    }
                    Button("Edit Keywords…") { editingKeywords = true }
                        .controlSize(.small)
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(40)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $editingKeywords) {
            EditKeywordsView(pawn: pawn) { library.correctTags($0, of: pawn.id) }
        }
    }
}

/// Lets the user correct a pawn's tags, as a comma-separated list.
struct EditKeywordsView: View {
    let pawn: Pawn
    let save: ([String]) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("Keywords", text: $text, prompt: Text("dwarf, undead, hammer"))
            Text("Separate keywords with commas. Tagging won't change keywords you've edited.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 420)
        .onAppear { text = pawn.tags.joined(separator: ", ") }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save(PawnTags.parsed(text))
                    dismiss()
                }
            }
        }
    }
}
