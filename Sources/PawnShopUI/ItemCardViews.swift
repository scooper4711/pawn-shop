import PawnShopCore
import SwiftUI

/// An item's card, rendered in the background.
struct ItemCardThumbnail: View {
    let card: ItemCardContent
    /// Pixel height to render: a tile's, sharp on a Retina display, unless asked for larger, as by the preview.
    var pixelHeight = BackgroundRenderer.thumbnailHeight
    @Environment(LibraryModel.self) private var library
    @AppStorage(ItemCardPreferences.artOpacityKey) private var opacity = Double(ItemCard.defaultArtOpacity)
    @AppStorage(ItemCardPreferences.printsBackgroundsKey) private var printsBackgrounds = true
    @AppStorage(ItemCardPreferences.smallestTextSizeKey)
    private var smallestTextSize = Double(ItemCard.defaultSmallestTextSize)
    @State private var image: CGImage?

    /// Changes with the card settings, so the card is drawn again.
    private var looks: String { "\(opacity)-\(printsBackgrounds)-\(smallestTextSize)" }

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 2).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                    .aspectRatio(ItemCard.size.width / ItemCard.size.height, contentMode: .fit)
            }
        }
        .task(id: "\(card.item.id)-\(card.card)-\(card.artwork?.id.uuidString ?? "")-\(looks)") {
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Item Preview")
    }
}
