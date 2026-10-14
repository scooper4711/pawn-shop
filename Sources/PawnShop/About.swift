import AppNotices
import Foundation

extension AboutInfo {
    /// Pawn Shop's About panel. The credits match the README's License section.
    static let pawnShop = AboutInfo(
        appName: "Pawn Shop",
        tagline: "An unofficial, free app that prints just the pawns you need from your pawn PDFs.",
        credits: [
            "Item card text comes from the pf2e system for Foundry VTT and is used under the ORC License and the "
                + "Open Game License 1.0a, whose notices ship with the app.",
            "The item cards' parchment, frames and panels are Rexard game dev assets, used under license.",
            "The action icons are Paizo's Pathfinder-Icons font, used unaltered under the Paizo Compatibility "
                + "License."
        ],
        // A literal URL that is known to parse.
        // swiftlint:disable:next force_unwrapping
        contactURL: URL(string: "https://github.com/scooper4711/pawn-shop/issues")!
    )
}
