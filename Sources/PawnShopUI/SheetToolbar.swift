import SwiftUI

extension View {
    /// Shows a sheet's toolbar buttons (Cancel, Rename, Add Pawn…) on the iPad too: there a sheet shows them only
    /// in a navigation bar, so the sheet sits in a `NavigationStack`. The Mac shows them at the sheet's foot as is.
    func sheetToolbar(title: String) -> some View {
        modifier(SheetToolbar(title: title))
    }
}

private struct SheetToolbar: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        #if os(iOS)
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
        #else
        content
        #endif
    }
}
