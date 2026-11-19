import Foundation
import PawnShopCore

/// Items and spells, and the cards they print as.
extension LibraryModel {
    func searchItems(_ query: ItemQuery) -> [CatalogItem] { catalog.search(query) }

    /// How many cards the item's or spell's text takes (R8.3.1).
    func cardCount(for item: CatalogItem) -> Int {
        guard let renderer else { return 1 }
        ItemCardPreferences.apply(to: renderer)
        return renderer.cardCount(for: item)
    }

    /// An item's card, with the art an imported item deck prints for it.
    func card(for item: CatalogItem) -> ItemCardContent {
        ItemCardContent(item: item, artwork: ItemArtMatcher(artwork: itemArt, renames: catalog.renames)
            .artwork(for: item))
    }

    /// A card to show the art setting on: the first item an imported deck has art for, or else the first
    /// consumable; nil without a catalog.
    var sampleCard: ItemCardContent? {
        let matcher = ItemArtMatcher(artwork: itemArt, renames: catalog.renames)
        let item = catalog.items.first { matcher.artwork(for: $0) != nil }
            ?? catalog.items.first { $0.kind == .consumable }
        return item.map(card(for:))
    }
}
