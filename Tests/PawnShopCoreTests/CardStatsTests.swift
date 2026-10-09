import Testing
@testable import PawnShopCore

@Suite struct CardStatsTests {
    @Test func readsAPathfinderCard() {
        let text = "AEON, ARBITER\u{8} CREATURE 1\nLN TINY AEON INEVITABLE MONITOR\nPerception +7; darkvision"
        #expect(CardStats.read(text) == CardStats(name: "Aeon, Arbiter", size: .medium,
                                                  traits: ["tiny", "aeon", "inevitable", "monitor"]))
    }

    @Test func readsTraitsWrappedOntoThePerceptionLine() {
        let text = "AEON, BYTHOS\t CREATURE 16\nUNCOMMON LN LARGE MONITOR\nAEON Perception +30; darkvision"
        #expect(CardStats.read(text) == CardStats(name: "Aeon, Bythos", size: .large,
                                                  traits: ["large", "monitor", "aeon"]))
    }

    @Test func takesTraitsReadOutOfOrderAwayFromTheName() {
        let before = CardStats.read("N TINY PSYCHOPOMP, NOSOI CREATURE 1\nMONITOR PSYCHOPOMP\nPerception +6")
        #expect(before == CardStats(name: "Psychopomp, Nosoi", size: .medium,
                                    traits: ["tiny", "monitor", "psychopomp"]))
        let after = CardStats.read("GRIM REAPER, LESSER DEATH RARE NE HUGE CREATURE 16\nUNDEAD\nPerception +30")
        #expect(after == CardStats(name: "Grim Reaper, Lesser Death", size: .huge, traits: ["huge", "undead"]))
    }

    @Test func keepsASizeOrRarityThatEndsTheName() {
        let stats = CardStats.read("HERD ANIMAL, HUGE CREATURE 4\nN HUGE ANIMAL\nPerception +9")
        #expect(stats?.name == "Herd Animal, Huge" && stats?.size == .huge)
        #expect(CardStats.read("SWAMP STRIDER, COMMON CREATURE 2\nN MEDIUM ANIMAL\nPerception +5")?.name
                    == "Swamp Strider, Common")
    }

    @Test func findsTheNameOnTheLineAboveItsLevel() {
        let stats = CardStats.read("ABBOT OF ABADAR\nCREATURE 1\nMEDIUM HUMAN HUMANOID\nPerception +7")
        #expect(stats?.name == "Abbot of Abadar" && stats?.traits == ["medium", "human", "humanoid"])
    }

    @Test(arguments: ["(Aeon, pleroma; continued from card 4)\nWherever the sphere travels CREATURE 5",
                      "SPIKED PIT HAZARD 0\nTRAP\nStealth DC 18", "This product is compliant with the OGL.", ""])
    func readsNothingFromOtherPages(text: String) {
        #expect(CardStats.read(text) == nil)
    }

    @Test func readsAStarfinderCard() {
        let text = "AEON, TEKHOINOS\u{8} CR 10\nXP 9,600\nN Medium outsider (aeon, extraplanar)\nInit +5"
        #expect(CardStats.read(text) == CardStats(name: "Aeon, Tekhoinos", size: .medium,
                                                  traits: ["medium", "outsider", "aeon", "extraplanar"]))
    }

    @Test func readsAStarfinderNameBeforeItsExperienceWhenTheRatingComesLater() {
        let text = "DRAGON, YOUNG ADULT BLUE\u{8} XP 12,800\nLE Huge dragon (earth)\n"
            + "Aura frightful presence (170 ft., DC 18)\nCR 11\nDEFENSE HP 183"
        #expect(CardStats.read(text) == CardStats(name: "Dragon, Young Adult Blue", size: .huge,
                                                  traits: ["huge", "dragon", "earth"]))
    }

    @Test func readsAStarfinderNameSharingItsLineWithTheType() {
        let text = "ROBOT, OBSERVER-CLASS SECURITY \u{8} N Small construct (technological; Starfinder Armory 70)\n"
            + "Init +4; Senses darkvision 60 ft.; Perception +5\nCR 1 XP 400"
        #expect(CardStats.read(text) == CardStats(name: "Robot, Observer-Class Security", size: .medium,
                                                  traits: ["small", "construct", "technological"]))
    }

    @Test func readsAStarfinderCardWithoutATypeLine() {
        #expect(CardStats.read("SWARM MIND CR 1/2\nXP 200") == CardStats(name: "Swarm Mind", size: .medium,
                                                                           traits: []))
    }

    @Test(arguments: [("Fine", PawnSize.medium), ("tiny", .medium), ("SMALL", .medium), ("Large", .large),
                      ("huge", .huge), ("Gargantuan", .gargantuan), ("Colossal", .gargantuan)])
    func sizesPawnsByTheCreaturesSize(word: String, size: PawnSize) {
        #expect(PawnSize.creature(word) == size)
    }

    @Test func knowsNoSizeForOtherWords() {
        #expect(PawnSize.creature("dragon") == nil)
    }
}
