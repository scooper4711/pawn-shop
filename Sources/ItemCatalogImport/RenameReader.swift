import CreatureImport
import Foundation

/// Reads the items the remaster renamed from the pf2e system's Remaster Changes journal: its Equipment page is a
/// table of old names and the new items, linked. Item decks printed before the remaster use the old names.
enum RenameReader {
    static let journal = "packs/pf2e/journals/remaster-changes.json"

    /// Each old name with its new one, as in "Thunderstone" → "Blasting Stone (Lesser)"; empty when the
    /// repository has no such journal.
    static func renames(in repository: URL) -> [String: String] {
        guard let document = try? JSONValue(contentsOf: repository.appendingPathComponent(journal)),
              let page = document["pages"].array.first(where: { $0["name"].string == "Equipment" })
        else { return [:] }
        return renames(inTable: page[path: "text.content"].string)
    }

    /// The renames in the table's rows; rows naming no new item ("Removed - …") are left out.
    static func renames(inTable html: String) -> [String: String] {
        var renames: [String: String] = [:]
        // The first row heads the columns.
        for row in html.matches(of: /<tr>([\s\S]*?)<\/tr>/).dropFirst() {
            let cells = String(row.output.1).matches(of: /<td[^>]*>([\s\S]*?)<\/td>/).map { String($0.output.1) }
            guard cells.count == 2 else { continue }
            let olds = oldNames(plainText(cells[0]))
            let news = newNames(cells[1])
            for (old, new) in pairs(olds, news) { renames[old] = new }
        }
        return renames
    }

    /// The items a new-name cell links to, or else its plain text unless it says the item was removed.
    static func newNames(_ cell: String) -> [String] {
        let linked = cell.matches(of: /@UUID\[[^\]]*?\.Item\.([^\]]+)\]/).map { String($0.output.1) }
        if !linked.isEmpty { return linked }
        let text = withoutVarious(plainText(cell))
        return text.isEmpty || text.hasPrefix("Removed") ? [] : [text]
    }

    /// The names an old-name cell lists: separated by commas, or several in parentheses after a shared name, as
    /// "Feather Token (Chest, Ladder, Swan Boat)".
    static func oldNames(_ text: String) -> [String] {
        if let match = text.wholeMatch(of: /(.+?) \(([^()]+,[^()]+)\)/) {
            let base = String(match.output.1)
            return match.output.2.split(separator: ",").map { "\(base) (\($0.trimmingCharacters(in: .whitespaces)))" }
        }
        return text.split(separator: ",", omittingEmptySubsequences: true)
            .map { withoutVarious($0.trimmingCharacters(in: .whitespaces)) }
            .reduce(into: [String]()) { names, part in
                // A comma inside parentheses belongs to the name before it.
                if let last = names.last, last.filter({ $0 == "(" }).count > last.filter({ $0 == ")" }).count {
                    names[names.count - 1] = last + ", " + part
                } else {
                    names.append(part)
                }
            }
    }

    /// Old and new names in order when there are as many of each, or else every old name with the first new one.
    private static func pairs(_ olds: [String], _ news: [String]) -> [(String, String)] {
        guard let first = news.first else { return [] }
        return olds.count == news.count ? Array(zip(olds, news)) : olds.map { ($0, first) }
    }

    private static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The name without "(various)", which stands for every grade.
    private static func withoutVarious(_ name: String) -> String {
        name.replacingOccurrences(of: #"\s*\(various\)"#, with: "", options: [.regularExpression, .caseInsensitive])
    }
}
