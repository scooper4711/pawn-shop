import Foundation
import ItemCatalogImport

/// `ItemImport --pf2e PF2E_REPO --out GENERATED_FOLDER`
///
/// Imports every Pathfinder and Starfinder item from the pf2e system repository into `<out>/Items`.
let arguments = Array(CommandLine.arguments.dropFirst())

func value(after flag: String) -> String? {
    arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
}

guard let repository = value(after: "--pf2e"), let output = value(after: "--out") else {
    FileHandle.standardError.write(Data("Usage: ItemImport --pf2e PF2E_REPO --out GENERATED_FOLDER\n".utf8))
    exit(2)
}
do {
    let report = try ItemImporter(repository: URL(fileURLWithPath: repository),
                                  outputDirectory: URL(fileURLWithPath: output)).run()
    print("Imported \(report.itemCount) items.")
} catch {
    FileHandle.standardError.write(Data("Importing the items failed: \(error)\n".utf8))
    exit(1)
}
