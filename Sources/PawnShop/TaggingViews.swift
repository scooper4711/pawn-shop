import PawnShopCore
import SwiftUI

/// While pawns are being tagged, a progress bar whose tooltip says how many are left; a warning when tagging
/// stopped.
struct TaggingStatus: View {
    private let tagging = PawnTaggingModel.shared

    var body: some View {
        if tagging.isRunning {
            let progress = tagging.progress
            ProgressView(value: progress.fraction)
                .frame(width: 60)
                .help("Tagging pawns with \(tagging.tagger.model): \(progress.summary)")
        } else if let problem = tagging.problem {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .help(problem + "\nLibrary › Tag New Pawns tries again.")
        }
    }
}

/// The Settings tab for tagging: whether to tag, with which model on which server, and how far it has come.
struct TaggingSettingsView: View {
    @Bindable var tagging: PawnTaggingModel

    var body: some View {
        Form {
            Toggle("Tag pawns with AI", isOn: $tagging.isOn)
            note("Tagging is optional: without it, search still finds pawns by name, product and trait. With it, "
                 + "a vision model describes each pawn's art in keywords you can search for, and suggests names "
                 + "for pawns printed without one. It needs Ollama, a free program you install yourself.")
            Link("How to Set Up Tagging", destination: OllamaTagger.guideURL)
            server
            CommittedTextField(title: "Model", placeholder: OllamaTagger.defaultModel, text: $tagging.modelName)
            note("Changing the model tags every pawn again.")
            progress
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder private var server: some View {
        CommittedTextField(title: "Server", placeholder: OllamaTagger.defaultEndpoint.absoluteString,
                           text: $tagging.serverAddress)
        note(TaggingSettingsText.serverNote(for: tagging.serverAddress))
    }

    private var progress: some View {
        let progress = tagging.progress
        return VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: progress.fraction)
            Text(progress.summary)
                .monospacedDigit()
            note(status(isComplete: progress.isComplete))
        }
        .padding(.top, 8)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func status(isComplete: Bool) -> String {
        if !tagging.isOn { return "Tagging is turned off." }
        if tagging.isRunning { return "Tagging with \(tagging.tagger.model)…" }
        if let problem = tagging.problem { return problem }
        if isComplete { return "Tagged with \(tagging.tagger.model)." }
        return "Library › Tag New Pawns tags the rest."
    }
}

/// A text field that hands on what was typed only on Return or when the field is left, so a half-typed model
/// name or address is never used.
private struct CommittedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: $draft, prompt: Text(placeholder))
            .focused($isFocused)
            .autocorrectionDisabled()
            .onAppear { draft = text }
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        if draft != text { text = draft }
    }
}
