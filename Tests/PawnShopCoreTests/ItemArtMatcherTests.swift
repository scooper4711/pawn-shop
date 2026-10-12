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

    @Test func findsArtUnderItsOldName() {
        let renames = ["Thunderstone": "Blasting Stone (Lesser)", "Sunrod": "Glow Rod"]
        let matcher = ItemArtMatcher(artwork: [art("Thunderstone"), art("Sunrod"), art("Glow Rod")],
                                     renames: renames)
        #expect(matcher.artwork(for: catalogItem("Blasting Stone (Lesser)", level: 1))?.name == "Thunderstone")
        #expect(matcher.artwork(for: catalogItem("Blasting Stone (Major)", level: 17))?.name == "Thunderstone")
        // Art printed under the new name wins over art printed under the old one.
        #expect(matcher.artwork(for: catalogItem("Glow Rod", level: 1))?.name == "Glow Rod")
    }

    @Test func findsArtTheDecksMisname() {
        let matcher = ItemArtMatcher(artwork: [art("Olefactory Obfuscator"), art("Feather Token, Boat")])
        #expect(matcher.artwork(for: catalogItem("Olfactory Obfuscator (Lesser)", level: 3))?.name
                == "Olefactory Obfuscator")
        #expect(matcher.artwork(for: catalogItem("Marvelous Miniature (Boat)", level: 5))?.name
                == "Feather Token, Boat")
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
