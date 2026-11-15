import CoreGraphics

/// A paper size to pick where there is no Page Setup (the iPad), each printed with a quarter-inch margin, which
/// suits most printers.
public enum NamedPaper: String, CaseIterable, Identifiable, Sendable {
    case letter, legal, a4, a3, tabloid

    public static let marginInches: CGFloat = 0.25

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .letter: "US Letter"
        case .legal: "US Legal"
        case .a4: "A4"
        case .a3: "A3"
        case .tabloid: "Tabloid"
        }
    }

    /// The paper's size in points, portrait.
    public var size: CGSize {
        switch self {
        case .letter: CGSize(width: 612, height: 792)
        case .legal: CGSize(width: 612, height: 1008)
        case .a4: CGSize(width: 595.28, height: 841.89)
        case .a3: CGSize(width: 841.89, height: 1190.55)
        case .tabloid: CGSize(width: 792, height: 1224)
        }
    }

    /// The paper with its margin.
    public var setup: PaperSetup {
        let margin = Self.marginInches * pointsPerInch
        return PaperSetup(paperSize: size, imageableRect: CGRect(origin: .zero, size: size)
            .insetBy(dx: margin, dy: margin))
    }
}

extension PaperSetup {
    /// The named paper this is, by its size to within a point; nil for a size Page Setup gave that has no name
    /// here. Setting it takes that paper with its margin.
    public var named: NamedPaper? {
        get {
            NamedPaper.allCases.first {
                abs($0.size.width - paperSize.width) < 1 && abs($0.size.height - paperSize.height) < 1
            }
        }
        set {
            if let newValue { self = newValue.setup }
        }
    }
}
