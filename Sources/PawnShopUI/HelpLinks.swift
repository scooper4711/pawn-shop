import Foundation

/// Web pages the app links to: in the Help menu on the Mac and in Settings on iPad.
enum HelpLinks {
    // Literal URLs that are known to parse.
    // swiftlint:disable force_unwrapping

    /// The privacy policy.
    static let privacyPolicy = URL(string: "https://github.com/scooper4711/pawn-shop/blob/main/PRIVACY.md")!

    /// The 3D-printable pawn bases: the STLs, the OpenSCAD source and the printing instructions in its README.
    static let pawnBases = URL(string: "https://github.com/scooper4711/pawn-shop/tree/main/pawn-bases")!

    // swiftlint:enable force_unwrapping
}
