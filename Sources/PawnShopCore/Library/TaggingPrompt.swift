import Foundation

/// What tagging asks the vision model. The pawn's name and game traits are already searchable, so the model is told
/// them and asked only for what the art adds: weapons, gear and other things particular to the picture.
public enum TaggingPrompt {
    /// Goes up whenever the prompts change what the keywords mean, so that every pawn is tagged again.
    public static let version = 2

    /// What the model was asked about, as stored with a pawn's tags: the model's name and the prompts' version.
    public static func signature(model: String) -> String { "\(model) v\(version)" }

    static let keywords = """
        List lowercase search keywords for what is visible in the art and particular to it: weapons held or worn \
        (the specific name and the general kind, as in longsword and sword, longbow and bow, rifle and gun), \
        shields, armor, notable gear and clothing (cloak, lantern, book, helmet, backpack), animals or mounts with \
        it, and striking features (wings, horns, tentacles, tail, flames). Never give a gender. Do not list colors, \
        or generic words such as fantasy, character, creature, art or figure. Only list things you are sure you \
        can see.
        """

    /// For a pawn with a printed name: only what the name and traits don't already say.
    static func named(_ name: String, traits: [String]) -> String {
        let known = traits.isEmpty ? "" : " Its game traits are: \(traits.joined(separator: ", "))."
        return """
            This is the art of a pawn (a standee) for a tabletop role-playing game. It is named "\(name)".\(known) \
            Search already finds it by that name and those traits, so do not repeat them or say what kind of being \
            it is. \(keywords) List at most 8 keywords; a pawn with nothing more to say gets an empty list.
            """
    }

    /// For a pawn printed without a name: its ancestry or kind too, and a name to suggest.
    static let unnamed = """
        This is the art of a pawn (a standee) for a tabletop role-playing game, printed without a name. First guess \
        its ancestry (human, elf, dwarf, halfling, gnome, orc, goblin, kobold, tiefling...) or, when it is not a \
        person, the kind of creature, robot or vehicle, and its role if obvious (guard, wizard, merchant, priest, \
        noble...). \(keywords) List at most 10 keywords. Also suggest a name of at most three words, like the names \
        printed on pawns: the ancestry or kind and the role, such as Elf Wizard, Goblin Archer or Dwarf Priest.
        """
}
