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
            Image(systemName: "bolt.horizontal.circle")
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
        switch model.availability {
        case .notInstalled: "Chưa tìm thấy Claude Code"
        case .loggedOut: "Claude Code chưa sẵn sàng"
        case .ready, nil: "Đang kiểm tra engine"
        }
    }
}

#Preview {
    EngineStatusView(model: .live())
}
