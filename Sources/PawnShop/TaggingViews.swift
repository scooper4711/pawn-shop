import PawnShopCore
import SwiftUI

/// While pawns are being tagged, a progress bar and how many are left; a warning when tagging stopped.
struct TaggingStatus: View {
    private let tagging = PawnTaggingModel.shared

    var body: some View {
        if tagging.isRunning {
            let progress = tagging.progress
            HStack(spacing: 4) {
                ProgressView(value: progress.fraction)
                    .frame(width: 60)
                Text("\(progress.remaining.formatted()) to tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .help("Tagging pawns with \(tagging.tagger.model): \(progress.summary)")
        } else if let problem = tagging.problem {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .help(problem + "\nLibrary › Tag New Pawns tries again.")
        }
    }
}

/// The Settings tab for tagging: whether to tag, and how far it has come.
struct TaggingSettingsView: View {
    @Bindable var tagging: PawnTaggingModel

    var body: some View {
        Form {
            Toggle("Tag pawns with AI", isOn: $tagging.isOn)
            Text("A vision model running in Ollama on this Mac describes each pawn's art in keywords you can "
                 + "search for. Nothing leaves your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            progress
        }
        .padding(20)
        .frame(width: 420)
    }

    private var progress: some View {
        let progress = tagging.progress
        return VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: progress.fraction)
            Text(progress.summary)
                .monospacedDigit()
            Text(status(isComplete: progress.isComplete))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private func status(isComplete: Bool) -> String {
        if tagging.isRunning { return "Tagging with \(tagging.tagger.model)…" }
        if let problem = tagging.problem { return problem }
        if isComplete { return "Tagged with \(tagging.tagger.model)." }
        return tagging.isOn ? "Library › Tag New Pawns tags the rest." : "Tagging is turned off."
    }
}
