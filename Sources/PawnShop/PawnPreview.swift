import PawnShopCore
import SwiftUI

/// A pawn's front and back shown large over the window, like Quick Look. Clicking outside it closes it.
struct PawnPreview: View {
    /// Tall enough to stay sharp at the size the preview reaches on a large display.
    static let pixelHeight = 1200

    let pawn: Pawn
    let close: () -> Void
    @Environment(LibraryModel.self) private var library

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
                if !pawn.tags.isEmpty {
                    Text(pawn.tags.joined(separator: ", ")).font(.callout).foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(40)
        }
        .ignoresSafeArea()
    }
}
