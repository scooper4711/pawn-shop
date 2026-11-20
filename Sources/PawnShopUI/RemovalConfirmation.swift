import PawnShopCore
import SwiftUI

/// Pawns waiting for the user's answer before they are removed, with the question to ask (R2.5).
struct PendingRemoval: Identifiable {
    let id = UUID()
    let ids: Set<UUID>
    let warning: RemovalWarning
}

extension View {
    /// Asks before removing pawns when that deletes custom pawns from every app; Delete calls `remove`.
    func confirmsRemoval(_ removal: Binding<PendingRemoval?>, remove: @escaping (Set<UUID>) -> Void) -> some View {
        alert(removal.wrappedValue?.warning.title ?? "", isPresented: Binding(
            get: { removal.wrappedValue != nil }, set: { if !$0 { removal.wrappedValue = nil } }
        ), presenting: removal.wrappedValue) { pending in
            Button("Delete", role: .destructive) { remove(pending.ids) }
            Button("Cancel", role: .cancel) { /* the alert closes itself */ }
        } message: { pending in
            Text(pending.warning.message)
        }
    }
}
