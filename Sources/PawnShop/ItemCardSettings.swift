import PawnShopCore
import SwiftUI

/// How item and spell cards are printed, as the user sets it in Settings.
enum ItemCardPreferences {
    static let artOpacityKey = "itemArtOpacity"
    static let printsBackgroundsKey = "printsCardBackgrounds"

    /// Whether cards print on their Rexard backgrounds (R8.7); on unless turned off.
    static var printsBackgrounds: Bool {
        UserDefaults.standard.object(forKey: printsBackgroundsKey) as? Bool ?? true
    }

    /// Sets the user's card settings on a renderer.
    static func apply(to renderer: PawnRenderer) {
        renderer.itemArtOpacity = artOpacity
        renderer.printsCardBackgrounds = printsBackgrounds
    }

    /// Changes when a card's look does, for keeping rendered cards apart.
    static var cacheKey: String { "\(artOpacity)-\(printsBackgrounds)" }

    /// How opaque an item's art is behind its card's text, from 0 (none) to 1.
    static var artOpacity: CGFloat {
        (UserDefaults.standard.object(forKey: artOpacityKey) as? Double).map { CGFloat($0) }
            ?? ItemCard.defaultArtOpacity
    }
}

/// The Settings window's Item Cards tab: whether cards print their backgrounds, and how visible the item's art is
/// behind the text, with a card to see them on.
struct ItemCardSettingsView: View {
    @AppStorage(ItemCardPreferences.artOpacityKey) private var opacity = Double(ItemCard.defaultArtOpacity)
    @AppStorage(ItemCardPreferences.printsBackgroundsKey) private var printsBackgrounds = true
    @Environment(LibraryModel.self) private var library

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Form {
                Toggle("Print card backgrounds", isOn: $printsBackgrounds)
                Text("Item and spell cards print on parchment or a sci-fi panel. Turn this off to print them on "
                     + "white and save ink.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
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
