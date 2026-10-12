import Foundation
import Testing
import ArtExtraction
@testable import PawnShopCore

/// Finding an item's deck art by its name.
@Suite struct ItemArtMatcherTests {
    let artwork = [art("Healing Potion"), art("Lesser Acid Flask"), art("Alchemist's Fire"), art("Cat’s Eye Elixir")]

    @Test func matchesTheSameWordsInAnyOrder() {
        let matcher = ItemArtMatcher(artwork: artwork)
        #expect(matcher.artwork(for: catalogItem("Acid Flask (Lesser)", level: 1))?.name == "Lesser Acid Flask")
        #expect(matcher.artwork(for: catalogItem("alchemists fire", level: 1))?.name == "Alchemist's Fire")
        #expect(matcher.artwork(for: catalogItem("Cat's Eye Elixir", level: 5))?.name == "Cat’s Eye Elixir")
    }

    @Test func fallsBackToTheNameWithoutItsGrade() {
        let matcher = ItemArtMatcher(artwork: artwork)
        #expect(matcher.artwork(for: catalogItem("Healing Potion (Minor)", level: 1))?.name == "Healing Potion")
        #expect(matcher.artwork(for: catalogItem("Acid Flask (Greater)", level: 1))?.name == "Lesser Acid Flask")
        #expect(matcher.artwork(for: catalogItem("Longsword", level: 0)) == nil)
    }

    @Test func prefersTheExactGradeOverTheBaseName() {
        let matcher = ItemArtMatcher(artwork: [art("Healing Potion"), art("Healing Potion (Minor)")])
        #expect(matcher.artwork(for: catalogItem("Healing Potion (Minor)", level: 1))?.name
                == "Healing Potion (Minor)")
    }
}

func art(_ name: String, file: String = "art.png") -> ItemArtwork {
    ItemArtwork(name: name, sourceID: "deck", picture: .drawn(file: file),
                fingerprint: ArtFingerprint(imageDigests: [name]))
}
