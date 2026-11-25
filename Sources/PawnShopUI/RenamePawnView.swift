import PawnShopCore
import SwiftUI

/// Asks for a pawn's new name.
struct RenamePawnView: View {
    let pawn: Pawn
    let rename: (String) -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("Name", text: $name)
        }
        .padding()
        .frame(width: 320)
        .onAppear { name = pawn.name }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Rename") {
                    rename(name)
                    dismiss()
                }
            }
        }
        .sheetToolbar(title: "Rename Pawn")
    }
}
