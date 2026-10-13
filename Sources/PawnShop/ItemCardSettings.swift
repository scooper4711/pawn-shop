import PawnShopCore
import SwiftUI

/// How item cards are printed, as the user sets it in Settings.
enum ItemCardPreferences {
    static let artOpacityKey = "itemArtOpacity"

    /// How opaque an item's art is behind its card's text, from 0 (none) to 1.
    static var artOpacity: CGFloat {
        (UserDefaults.standard.object(forKey: artOpacityKey) as? Double).map { CGFloat($0) }
            ?? ItemCard.defaultArtOpacity
    }
}

/// The Settings window's Item Cards tab: how visible the item's art is behind the text, with a card to see it on.
struct ItemCardSettingsView: View {
    @AppStorage(ItemCardPreferences.artOpacityKey) private var opacity = Double(ItemCard.defaultArtOpacity)
    @Environment(LibraryModel.self) private var library

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Form {
                Slider(value: $opacity, in: 0...1) {
                    Text("Art behind the text")
                } minimumValueLabel: {
                    Text("None")
                } maximumValueLabel: {
                    Text("Solid")
                }
                Text("\(Int((opacity * 100).rounded()))% opaque")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("When an item deck you imported prints the item, its picture is drawn behind the card's text. "
                     + "Fainter art keeps the text easy to read.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Restore Default") { opacity = Double(ItemCard.defaultArtOpacity) }
                    .disabled(opacity == Double(ItemCard.defaultArtOpacity))
            }
            if let card = library.sampleCard {
                ItemCardThumbnail(card: card, pixelHeight: 640)
                    .frame(width: 180, height: 252)
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
