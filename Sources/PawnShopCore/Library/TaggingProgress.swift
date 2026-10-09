import Foundation

/// How many of the library's pawns a tagging model has tagged, and how many are left.
public struct TaggingProgress: Equatable, Sendable {
    public let done: Int
    public let total: Int

    public init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }

    /// Counts the pawns `model` still has to tag (`Pawn.needsTagging(by:)`) against all of them.
    public init(of pawns: [Pawn], by model: String) {
        let left = pawns.count(where: { $0.needsTagging(by: model) })
        self.init(done: pawns.count - left, total: pawns.count)
    }

    public var remaining: Int { total - done }

    public var isComplete: Bool { remaining == 0 }

    /// From 0 to 1; an empty library counts as finished.
    public var fraction: Double { total == 0 ? 1 : Double(done) / Double(total) }

    /// Such as "312 of 340 pawns tagged, 28 left".
    public var summary: String {
        guard total > 0 else { return "No pawns to tag" }
        let tagged = "\(done.formatted()) of \(total.formatted()) \(total == 1 ? "pawn" : "pawns") tagged"
        return isComplete ? tagged : "\(tagged), \(remaining.formatted()) left"
    }
}

public extension Pawn {
    /// True when `model` hasn't tagged the pawn (unless the user corrected its tags), or it needs a name and has
    /// no suggestion yet.
    func needsTagging(by model: String) -> Bool {
        (tagModel != model && !tagsCorrected) || (needsName && suggestedName.isEmpty)
    }
}
