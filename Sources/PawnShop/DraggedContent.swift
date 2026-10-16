import CoreTransferable
import SwiftUI
import PawnShopCore
import UniformTypeIdentifiers

extension UTType {
    static let sheetContent = UTType(exportedAs: "com.github.scooper4711.sheetcontent")
}

/// The pawns or item cards dragged from the library to the sheet.
struct DraggedContent: Codable, Transferable {
    let contents: [SheetContent]

    init(_ contents: [SheetContent]) {
        self.contents = contents
    }

    /// The selection when the dragged tile is part of it, else the dragged tile alone.
    static func dragging<ID: Hashable>(_ id: ID, selection: Set<ID>, order: @autoclosure () -> [ID],
                                       content: (ID) -> SheetContent) -> DraggedContent {
        guard selection.contains(id) else { return DraggedContent([content(id)]) }
        return DraggedContent(order().filter(selection.contains).map(content))
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .sheetContent)
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
