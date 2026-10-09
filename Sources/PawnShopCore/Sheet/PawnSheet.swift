import CoreGraphics
import Foundation

/// How strips are separated for cutting.
public enum CutStyle: Codable, Hashable, Sendable {
    /// Strips touch, so one cut separates two pawns.
    case sharedLines
    /// Strips are this many points apart, each with its own outline.
    case gaps(CGFloat)

    /// The default gap: a tenth of an inch.
    public static let defaultGap: CGFloat = 7.2

    var spacing: CGFloat {
        switch self {
        case .sharedLines: 0
        case .gaps(let points): max(0, points)
        }
    }
}

/// The paper a sheet is printed on.
public struct PaperSetup: Codable, Hashable, Sendable {
    public var paperSize: CGSize
    /// The area the printer can print, in page coordinates (origin bottom left).
    public var imageableRect: CGRect

    public init(paperSize: CGSize, imageableRect: CGRect) {
        self.paperSize = paperSize
        self.imageableRect = imageableRect
    }

    /// US Letter with quarter-inch margins.
    public static let letter = PaperSetup(paperSize: CGSize(width: 612, height: 792),
                                          imageableRect: CGRect(x: 18, y: 18, width: 576, height: 756))
}

public struct SheetSettings: Codable, Hashable, Sendable {
    /// The room left by default under each face for a base: the depth of the slot in the bases the app comes with
    /// (`slot_depth` in `pawn-bases/pawn_base.scad`), 6 mm.
    public static let defaultBaseRoom: CGFloat = .millimeters(6)

    public var cutStyle: CutStyle = .sharedLines
    public var showsFoldLine = true
    public var paper: PaperSetup = .letter
    /// Whether each face gets blank room below its foot, so the base's slot hides that room rather than the name.
    public var leavesRoomForBase = false
    /// How much room, in points; kept while `leavesRoomForBase` is off.
    public var baseRoom = SheetSettings.defaultBaseRoom

    public init(cutStyle: CutStyle = .sharedLines, showsFoldLine: Bool = true, paper: PaperSetup = .letter) {
        self.cutStyle = cutStyle
        self.showsFoldLine = showsFoldLine
        self.paper = paper
    }

    /// The blank room below each face's foot: `baseRoom` when room is left for a base, else none.
    public var footRoom: CGFloat { leavesRoomForBase ? max(0, baseRoom) : 0 }

    private enum CodingKeys: String, CodingKey { case cutStyle, showsFoldLine, paper, leavesRoomForBase, baseRoom }

    /// Sheets saved before room for a base existed leave none.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cutStyle = try container.decode(CutStyle.self, forKey: .cutStyle)
        showsFoldLine = try container.decode(Bool.self, forKey: .showsFoldLine)
        paper = try container.decode(PaperSetup.self, forKey: .paper)
        leavesRoomForBase = try container.decodeIfPresent(Bool.self, forKey: .leavesRoomForBase) ?? false
        baseRoom = try container.decodeIfPresent(CGFloat.self, forKey: .baseRoom) ?? Self.defaultBaseRoom
    }
}

/// A pawn on a sheet, with how many copies to print.
public struct SheetEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var pawnID: UUID
    public var count: Int

    public init(id: UUID = UUID(), pawnID: UUID, count: Int) {
        self.id = id
        self.pawnID = pawnID
        self.count = count
    }
}

/// The pawns chosen for printing: the contents of a `.pawnsheet` document.
public struct PawnSheet: Codable, Hashable, Sendable {
    public var entries: [SheetEntry] = []
    public var settings = SheetSettings()

    public init(entries: [SheetEntry] = [], settings: SheetSettings = SheetSettings()) {
        self.entries = entries
        self.settings = settings
    }

    public var copyCount: Int { entries.reduce(0) { $0 + $1.count } }

    /// Adds copies of a pawn, to its existing entry when it has one.
    public mutating func add(_ pawnID: UUID, copies: Int = 1) {
        guard copies > 0 else { return }
        if let index = entries.firstIndex(where: { $0.pawnID == pawnID }) {
            entries[index].count += copies
        } else {
            entries.append(SheetEntry(pawnID: pawnID, count: copies))
        }
    }

    /// Sets an entry's copies; none removes it.
    public mutating func setCount(_ count: Int, of entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        if count > 0 {
            entries[index].count = count
        } else {
            entries.remove(at: index)
        }
    }

    /// Removes one copy of an entry, and the entry with its last copy.
    public mutating func removeCopy(of entryID: UUID) {
        guard let entry = entries.first(where: { $0.id == entryID }) else { return }
        setCount(entry.count - 1, of: entryID)
    }

    public mutating func remove(_ entryID: UUID) {
        entries.removeAll { $0.id == entryID }
    }
}
