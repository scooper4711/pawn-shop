import CoreTransferable
import SwiftUI
import PawnShopCore
import UniformTypeIdentifiers

extension UTType {
    static let sheetContent = UTType(exportedAs: "com.github.scooper4711.PawnShop.sheet-content")
}

/// The pawns or item cards dragged from the library to the sheet, with the copies of each the add bar is set to.
struct DraggedContent: Codable, Transferable {
    let contents: [SheetContent]
    let copies: Int

    init(_ contents: [SheetContent], copies: Int) {
        self.contents = contents
        self.copies = copies
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .sheetContent)
    }
}

extension Set {
    /// What dragging the tile `id` carries when this is the selection: the selection, in `order`, when the tile is
    /// part of it, else the tile alone.
    func dragged(_ id: Element, order: @autoclosure () -> [Element]) -> [Element] {
        contains(id) ? order().filter(contains) : [id]
    }
}

extension View {
    /// A library tile: a click selects at once, a double-click adds, and a drag carries `payload` to the sheet.
    /// The double-click is simultaneous so the click needn't wait to rule it out.
    func libraryTile(dragging payload: DraggedContent, select: @escaping () -> Void,
                     add: @escaping () -> Void) -> some View {
        onTapGesture(perform: select)
            .simultaneousGesture(TapGesture(count: 2).onEnded(add))
            .draggable(payload)
    }
}

/// The files dropped on the window, to import.
enum DroppedFiles {
    /// Calls `completion` on the main thread with the file URLs `providers` carry; those that can't be read are
    /// left out.
    static func load(from providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
        let group = DispatchGroup()
        let found = FoundURLs()
        for provider in providers {
            group.enter()
            _ = provider.loadTransferable(type: URL.self) { result in
                if let url = try? result.get() { found.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) { MainActor.assumeIsolated { completion(found.urls) } }
    }

    /// URLs gathered from several loading threads.
    private final class FoundURLs: @unchecked Sendable {
        private let lock = NSLock()
        private var gathered: [URL] = []

        var urls: [URL] { lock.withLock { gathered } }

        func append(_ url: URL) { lock.withLock { gathered.append(url) } }
    }
}
