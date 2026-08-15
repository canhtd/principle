import PrincipleCore
import SwiftUI

/// Shown instead of the chat when the engine cannot run a turn (AE5).
///
/// It says what is wrong and what to type, because the fix always happens in a
/// terminal — the app cannot log anybody in.
struct EngineStatusView: View {
    let model: SessionViewModel
    @State private var isChecking = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(title)
                .font(Typography.title)
                .lineSpacing(Typography.titleLineSpacing)

            Text(model.engineGuidance ?? "")
                .vietnameseBody()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .textSelection(.enabled)

            Button(isChecking ? "Đang kiểm tra…" : "Kiểm tra lại") {
                isChecking = true
                Task {
                    await model.refreshAvailability()
                    isChecking = false
                }
            }
            .disabled(isChecking)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        model.availability?.blockedTitle ?? EngineAvailability.checkingTitle
    }

    /// A wrong repo is a folder problem, not an engine problem — saying so in the
    /// icon saves the user reading the paragraph to find that out.
    private var icon: String {
        if case .skillMissing = model.availability { return "folder.badge.questionmark" }
        return "bolt.horizontal.circle"
    }
}

#Preview {
    EngineStatusView(model: .live())
}
