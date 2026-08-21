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
/// over the grid, or docked as column 3's pane — between the principle of the
/// day and the bookmarks, which #18 keeps at the column's two ends whatever is
/// in the middle. Identical in both, down to the chrome bar its size.
///
/// The engine is the one the app already had — this is Eden's chat pane built
/// around ``SessionViewModel``, not a second chat. The pane is three pieces that
/// do not scroll together: a header, a thread that scrolls, and a composer
/// pinned under it.
struct AskRayPanel: View {
    @Bindable var session: SessionViewModel
    let favorites: FavoritesModel
    @Bindable var ui: DayShellState
    let isDocked: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(EdenColor.canvas)
        .clipShape(.rect(cornerRadius: radius, style: .continuous))
        .edenBorder(EdenColor.black(isDocked ? 6 : 10), radius: radius)
        .modifier(FloatingShadow(isFloating: !isDocked))
    }

    private var radius: CGFloat { isDocked ? EdenRadius.md : EdenRadius.lg }

    /// h62, and no rule under it: the thread's own day divider is the first line
    /// on the pane, and two horizontals that close together read as a toolbar.
    private var header: some View {
        HStack(spacing: RayChat.partGap) {
            Text("Ask Ray")
                .font(EdenFont.ui(13.5))
                .foregroundStyle(RayChat.title)
            Spacer(minLength: 0)
            RayIconButton(
                systemImage: isDocked ? "rectangle.inset.bottomright.filled" : "sidebar.right",
                help: isDocked ? "Float" : "Open as sidebar"
            ) {
                ui.setChatMode(isDocked ? .floating : .docked)
            }
            RayIconButton(systemImage: "xmark", help: "Close") { ui.closeChat() }
        }
        .padding(.top, RayChat.headerPaddingTop)
        .padding(.horizontal, RayChat.headerPaddingH)
        .padding(.bottom, RayChat.headerPaddingBottom)
        .frame(height: RayChat.headerHeight)
    }

    /// A chat with nothing in it yet is the same pane with an empty thread — no
    /// headline and no button to press first. The first question is what opens
    /// the consultation, so there is nothing to name in advance.
    @ViewBuilder
    private var content: some View {
        if session.isEngineBlocked {
            EngineStatusView(model: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            AskRayThread(model: session, favorites: favorites, ui: ui)
            AskRayComposer(model: session, send: send, canSend: canSend)
        }
    }

    /// Not ``SessionViewModel/canSend``: that one wants a session already open,
    /// and here the first question is what opens it.
    private var canSend: Bool {
        !session.canStop && !session.isEngineBlocked
            && !session.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The first question names the consultation and is then asked, which is
    /// what the old "What is going on?" screen did in two steps.
    private func send() {
        let question = session.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !session.canStop else { return }
        if session.currentSession == nil {
            var draft = AppSettings().newSessionDraft()
            draft.topic = question
            session.createSession(from: draft)
            // A session that could not be written leaves the question in the
            // composer rather than swallowing it.
            guard session.currentSession != nil else { return }
        }
        Task { await session.send(question) }
    }
}

/// The floating panel casts a shadow over the day. The docked one sits *on*
/// column 3's panel between the principle card and the bookmarks (#18), so it
/// wears the same 1.5 pt lift the principle card does — a panel shadow inside a
/// panel reads as a second window.
private struct FloatingShadow: ViewModifier {
    let isFloating: Bool

    func body(content: Content) -> some View {
        if isFloating {
            content.shadow(color: EdenColor.black(18), radius: 30, y: 22)
        } else {
            content.shadow(color: EdenColor.black(4), radius: 1.5, y: 1)
        }
    }
}
