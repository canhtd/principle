import PrincipleCore
import SwiftUI

/// Names the consultation before it starts (R1). "Create" stays off until the
/// topic has something in it — the rule lives in `NewSessionDraft`.
struct NewSessionSheet: View {
    /// Opens on the model chosen in Settings, so a change there applies to the
    /// next session without touching the ones already on disk (AE4).
    @State private var draft = AppSettings().newSessionDraft()
    let create: (NewSessionDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Session")
                .font(Typography.title)
                .lineSpacing(Typography.titleLineSpacing)

            VStack(alignment: .leading, spacing: 6) {
                Text("Topic")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $draft.topic, prompt: Text("For example: whether to change jobs"))
                    .textFieldStyle(.roundedBorder)
                    .font(Typography.body)
                    .onSubmit { if draft.canCreate { submit() } }
            }

            Picker("Model", selection: $draft.model) {
                ForEach(ModelAlias.all, id: \.self) { alias in
                    Text(ModelAlias.displayName(alias)).tag(alias)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.canCreate)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func submit() {
        create(draft)
        dismiss()
    }
}

#Preview {
    NewSessionSheet { _ in }
}
