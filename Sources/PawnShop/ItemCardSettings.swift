import PawnShopCore
import SwiftUI

/// How item and spell cards are printed, as the user sets it in Settings.
enum ItemCardPreferences {
    static let artOpacityKey = "itemArtOpacity"
    static let printsBackgroundsKey = "printsCardBackgrounds"
    static let smallestTextSizeKey = "smallestCardTextSize"

    /// How small a card's text may be set to save a card (R8.3.1).
    static var smallestTextSize: CGFloat {
        (UserDefaults.standard.object(forKey: smallestTextSizeKey) as? Double).map { CGFloat($0) }
            ?? ItemCard.defaultSmallestTextSize
    }

    /// Whether cards print on their Rexard backgrounds (R8.7); on unless turned off.
    static var printsBackgrounds: Bool {
        UserDefaults.standard.object(forKey: printsBackgroundsKey) as? Bool ?? true
    }

    /// Sets the user's card settings on a renderer.
    static func apply(to renderer: PawnRenderer) {
        renderer.itemArtOpacity = artOpacity
        renderer.printsCardBackgrounds = printsBackgrounds
        renderer.smallestCardTextSize = smallestTextSize
    }

    /// Changes when a card's look does, for keeping rendered cards apart.
    static var cacheKey: String { "\(artOpacity)-\(printsBackgrounds)-\(smallestTextSize)" }

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
    @AppStorage(ItemCardPreferences.smallestTextSizeKey)
    private var smallestTextSize = Double(ItemCard.defaultSmallestTextSize)
    @Environment(LibraryModel.self) private var library

    /// The sizes offered, largest first.
    private static let textSizes = Array(stride(from: Double(ItemCard.smallestTextSizes.upperBound),
                                                through: Double(ItemCard.smallestTextSizes.lowerBound), by: -0.25))

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Form {
                Toggle("Print card backgrounds", isOn: $printsBackgrounds)
                Text("Pathfinder cards print on parchment in a wooden frame, and Starfinder cards in a cyan frame. "
                     + "Turn this off to print them on white with a gray frame and save ink.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                Picker("Smallest text size", selection: $smallestTextSize) {
                    ForEach(Self.textSizes, id: \.self) { size in
                        Text(size == Double(ItemCard.defaultSmallestTextSize) ? "\(size.formatted()) pt (default)"
                             : "\(size.formatted()) pt").tag(size)
                    }
                }
                Text("Card text is 7 pt. Text a little too long for its card is set smaller, down to this size, "
                     + "when that saves a card; smaller sizes mean fewer cards but harder reading.")
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
