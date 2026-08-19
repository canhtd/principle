import DesignSystem
import PrincipleCore
import SwiftUI

/// Shown instead of the chat when the engine cannot run a turn (AE5).
///
/// It says what is wrong and what to type, because the fix always happens in a
/// terminal — the app cannot log anybody in. It is drawn inside the Ask Ray
/// pane, so it is set in the pane's own type and ink, not the window's.
struct EngineStatusView: View {
    let model: SessionViewModel
    @State private var isChecking = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(RayChat.muted)

            Text(title)
                .edenText(EdenType.sectionTitle)
                .foregroundStyle(RayChat.ink)
                .multilineTextAlignment(.center)

            Text(model.engineGuidance ?? "")
                .font(EdenFont.ui(RayChat.bodySize))
                // The leading, not the size, is what Vietnamese needs: its marks
                // sit above *and* below the line.
                .lineSpacing(RayChat.bodySize * (RayChat.bodyLineHeight - 1))
                .foregroundStyle(RayChat.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: EdenMetric.emptyStateMaxWidth)
                .textSelection(.enabled)

            Button(isChecking ? "Checking…" : "Check Again") {
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
