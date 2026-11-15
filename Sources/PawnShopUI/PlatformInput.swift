import SwiftUI

#if os(macOS)
import AppKit
#endif

/// How a click in the library's grids is read: on the Mac, Command-click adds to the selection or takes a pawn out
/// of it. On the iPad a tap selects one, and the selection is added with its button.
@MainActor
enum SelectionClick {
    static var extendsSelection: Bool {
        #if os(macOS)
        NSEvent.modifierFlags.contains(.command)
        #else
        false
        #endif
    }
}

extension View {
    /// The Delete key on the Mac; the iPad removes copies with the inspector's buttons instead.
    func deleteCommand(perform action: @escaping () -> Void) -> some View {
        #if os(macOS)
        onDeleteCommand(perform: action)
        #else
        self
        #endif
    }
}
