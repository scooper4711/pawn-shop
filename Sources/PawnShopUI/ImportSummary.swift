import PawnShopCore

/// What a batch of imports tells the user (R1.8).
extension LibraryModel {
    static func summary(of reports: [ImportReport], failures: [String]) -> String {
        let added = reports.reduce(0) { $0 + $1.added }
        let borrowed = reports.reduce(0) { $0 + $1.namedFromOtherProducts }
        let needingNames = reports.reduce(0) { $0 + $1.needingNames }
        let itemArt = reports.reduce(0) { $0 + $1.itemArtAdded }
        let empty = reports.filter { !$0.reread && $0.added + $0.alreadyKnown + $0.itemArtAdded == 0 }
            .map(\.sourceTitle)
        let reread = reports.filter(\.reread).count
        let flattened = reports.filter { !$0.unreadablePages.isEmpty }
            .map { "\($0.sourceTitle) (\($0.unreadablePages.count) pages)" }
        var lines = ["Added \(added) pawns from \(reports.count) PDF\(reports.count == 1 ? "" : "s")."]
        if itemArt > 0 { lines.append("Kept the art of \(itemArt) items for their cards.") }
        lines += mergingNotes(of: reports)
        if borrowed > 0 {
            lines.append("\(borrowed) pawns with no name printed took the name of the same art elsewhere.")
        }
        if needingNames > 0 {
            lines.append("\(needingNames) pawns have no name yet; name them with Library › Review Unnamed Pawns.")
        }
        if reread > 0 {
            lines.append("\(reread) PDF\(reread == 1 ? " was" : "s were") read again by the newer reader, adding only "
                         + "the pawns it found anew.")
        }
        if !empty.isEmpty { lines.append("No pawns were found in: \(empty.joined(separator: ", ")).") }
        if !flattened.isEmpty {
            lines.append("Some pages print their pawns as one flat picture, which can't be split into pawns: "
                         + "\(flattened.joined(separator: ", ")).")
        }
        if !failures.isEmpty { lines.append("Could not import: \(failures.joined(separator: "; ")).") }
        return lines.joined(separator: "\n")
    }

    /// What the reports say about art the library had already, from other products.
    private static func mergingNotes(of reports: [ImportReport]) -> [String] {
        let known = reports.reduce(0) { $0 + $1.alreadyKnown }
        return known > 0 ? ["\(known) were already in the library from other products."] : []
    }
}
