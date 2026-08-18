import DesignSystem
import PrincipleCore
import SwiftUI

/// The way into the chat: a bubble on the window's right margin (decision 8),
/// not an icon in a header. It hides while the chat is up.
struct AskRayBubble: View {
    let open: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: open) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(EdenFont.ui(17))
                .foregroundStyle(EdenColor.primary5)
                .frame(width: DayMetric.bubbleSize, height: DayMetric.bubbleSize)
                .background(isHovering ? EdenColor.primary : EdenColor.primary80, in: .circle)
                .shadow(color: EdenColor.black(20), radius: 12, y: 6)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Ask Ray")
        .onHover { isHovering = $0 }
    }
}

/// The chat itself, in whichever of its two homes it is in: a panel floating
/// over the grid, or docked in place of column 3.
///
/// The engine is the one the app already had — this is a frame around
/// ``ChatView``, not a second chat.
struct AskRayPanel: View {
    @Bindable var session: SessionViewModel
    let favorites: FavoritesModel
    @Bindable var ui: DayShellState
    let isDocked: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            body(for: session)
        }
        .background(EdenColor.canvas)
        .clipShape(.rect(cornerRadius: isDocked ? EdenRadius.md : EdenRadius.lg, style: .continuous))
        .edenBorder(EdenColor.black(isDocked ? 6 : 10), radius: isDocked ? EdenRadius.md : EdenRadius.lg)
        .modifier(FloatingShadow(isFloating: !isDocked))
    }

    private var header: some View {
        HStack(spacing: EdenMetric.sidebarInset) {
            Text("Ask Ray")
                .font(EdenFont.ui(13.5))
                .foregroundStyle(EdenColor.hex(0x55524E))
            Spacer(minLength: 0)
            EdenIconButton(
                systemImage: isDocked ? "rectangle.inset.bottomright.filled" : "sidebar.right",
                help: isDocked ? "Float" : "Open as sidebar",
                size: 26
            ) {
                ui.setChatMode(isDocked ? .floating : .docked)
            }
            EdenIconButton(systemImage: "xmark", help: "Close", size: 26) { ui.closeChat() }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// A chat with nothing in it yet is one question away from having something,
    /// so the empty state is the question rather than a description of one.
    @ViewBuilder
    private func body(for session: SessionViewModel) -> some View {
        if session.isEngineBlocked {
            EngineStatusView(model: session)
        } else if session.currentSession != nil {
            ChatView(model: session, favorites: favorites)
        } else {
            StartConsultation(session: session)
        }
    }
}

/// The floating panel casts a shadow; the docked one is a column and does not.
private struct FloatingShadow: ViewModifier {
    let isFloating: Bool

    func body(content: Content) -> some View {
        if isFloating {
            content.shadow(color: EdenColor.black(18), radius: 30, y: 22)
        } else {
            content.edenPanelShadow()
        }
    }
}

/// Names the consultation and opens it, without the sheet the old window used —
/// a modal over a 380 pt panel would cover the thing it belongs to.
struct StartConsultation: View {
    @Bindable var session: SessionViewModel

    @State private var topic = ""

    var body: some View {
        VStack(alignment: .leading, spacing: EdenMetric.sidebarPadding) {
            Spacer(minLength: 0)
            Text("What is going on?")
                .font(EdenFont.ui(16, .medium))
                .foregroundStyle(EdenColor.textPrimary)
            Text("Name the situation, and Ray takes it from the book — not from memory.")
                .font(EdenFont.ui(13))
                .foregroundStyle(EdenColor.n500)
                .fixedSize(horizontal: false, vertical: true)
            TextField("For example: seven things on today, and I can't do them all", text: $topic)
                .textFieldStyle(.plain)
                .font(EdenFont.ui(13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(EdenColor.card, in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
                .edenBorder(EdenColor.black(10), radius: EdenRadius.sm)
                .onSubmit(start)
            Button("Start", action: start)
                .buttonStyle(EdenPrimaryButtonStyle())
                .disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer(minLength: 0)
        }
        .padding(EdenMetric.libraryPaddingTop)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func start() {
        var draft = AppSettings().newSessionDraft()
        draft.topic = topic
        session.createSession(from: draft)
        topic = ""
    }
}
