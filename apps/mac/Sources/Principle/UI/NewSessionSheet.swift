import PrincipleCore
import SwiftUI

/// Names the consultation before it starts (R1). "Tạo" stays off until the
/// topic has something in it — the rule lives in `NewSessionDraft`.
struct NewSessionSheet: View {
    @State private var draft = NewSessionDraft()
    let create: (NewSessionDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Phiên mới")
                .font(Typography.title)
                .lineSpacing(Typography.titleLineSpacing)

            VStack(alignment: .leading, spacing: 6) {
                Text("Chủ đề")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $draft.topic, prompt: Text("Ví dụ: Có nên đổi việc không"))
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
                Button("Huỷ", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Tạo") { submit() }
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
