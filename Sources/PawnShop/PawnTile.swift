import PawnShopCore
import SwiftUI

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
