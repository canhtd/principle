import DesignSystem
import PrincipleCore
import SwiftUI

/// The conversation, on Eden's measured chat pane (decision 12).
///
/// Two things make this read as Eden rather than as a generic transcript. The
/// gap between turns is not spacing — it is each message's own 14 pt of padding
/// meeting the next one's, so a turn is a self-contained block. And the two
/// speakers are shaped differently on purpose: the question is a bubble pushed
/// right, the answer is bare prose across the pane, because the answer is
/// long-form and a bubble around it would read as a chat message rather than as
/// something to sit and read.
struct AskRayThread: View {
    @Bindable var model: SessionViewModel
    let favorites: FavoritesModel
    @Bindable var ui: DayShellState

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scroller in
                ScrollView {
                    // Tail-aligned: a thread with two turns in it sits on the
                    // composer rather than floating at the top of the pane.
                    turns(width: proxy.size.width)
                        .frame(minHeight: proxy.size.height, alignment: .bottom)
                        .padding(.bottom, RayChat.partGap)
                }
                .scrollIndicators(.never)
                // A conversation is read from its end: the pane opens on the
                // latest turn and stays there as one streams in, rather than
                // opening on a question asked ten minutes ago.
                .defaultScrollAnchor(.bottom)
                // …and asked for again once the prose has been measured. The
                // anchor alone lands on the bottom of a thread whose Markdown
                // has not been laid out yet, which is short of the real one.
                .onAppear {
                    let last = model.messages.last?.id
                    DispatchQueue.main.async { scroll(scroller, to: last, animated: false) }
                }
                .onChange(of: model.streamingText) { _, _ in scroll(scroller, to: Self.streamingAnchor) }
                .onChange(of: model.messages.count) { _, _ in scroll(scroller, to: model.messages.last?.id) }
                .onChange(of: model.phase) { _, _ in scroll(scroller, to: Self.statusAnchor) }
            }
        }
    }

    @ViewBuilder
    private func turns(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let day = model.messages.first?.sentAt {
                DayDivider(date: day)
            }
            ForEach(model.messages) { message in
                AskRayTurn(
                    message: message,
                    cards: model.cards(for: message),
                    favorites: favorites,
                    ui: ui,
                    width: width
                )
                .id(message.id)
            }
            // Cards ride in on the finished turn: the ids arrive in the trailer,
            // at the very end, so a streaming answer is prose only.
            if model.isShowingActiveTurn, !model.visibleStreamingText.isEmpty {
                AskRayTurn(
                    message: ChatMessage(role: .assistant, text: model.visibleStreamingText),
                    cards: [],
                    favorites: favorites,
                    ui: ui,
                    width: width
                )
                .id(Self.streamingAnchor)
            }
            if model.isShowingActiveTurn, let status = model.statusLine {
                StatusLine(text: status).id(Self.statusAnchor)
            }
            if let error = model.errorMessage {
                ErrorNote(message: error, canResend: model.canResend) {
                    Task { await model.resend() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let streamingAnchor = "streaming"
    private static let statusAnchor = "status"

    private func scroll(_ proxy: ScrollViewProxy, to anchor: (some Hashable)?, animated: Bool = true) {
        guard let anchor else { return }
        guard animated else {
            proxy.scrollTo(anchor, anchor: .bottom)
            return
        }
        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(anchor, anchor: .bottom) }
    }
}

/// `.ccday` — the day a run of messages belongs to, between two hairlines.
private struct DayDivider: View {
    let date: Date

    var body: some View {
        HStack(spacing: RayChat.dayDividerGap) {
            line
            Text(label)
                .font(EdenFont.ui(RayChat.dayDividerSize))
                .foregroundStyle(RayChat.muted)
            line
        }
        .padding(.horizontal, RayChat.messagePaddingH)
        .padding(.top, RayChat.headerPaddingBottom)
    }

    private var line: some View {
        RayChat.warm(8).frame(height: 1).frame(maxWidth: .infinity)
    }

    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

/// The progress line while the engine works (KTD7) — a consultation runs for
/// minutes, and this is the only thing saying the app is still on it.
private struct StatusLine: View {
    let text: String

    var body: some View {
        HStack(spacing: RayChat.partGap) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(EdenFont.ui(12))
                .foregroundStyle(RayChat.muted)
        }
        .padding(.vertical, RayChat.messagePaddingV)
        .padding(.horizontal, RayChat.messagePaddingH)
    }
}

private struct ErrorNote: View {
    let message: String
    let canResend: Bool
    let resend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RayChat.partGap) {
            Text(message)
                .font(EdenFont.ui(12))
                .foregroundStyle(RayChat.ink)
                .fixedSize(horizontal: false, vertical: true)
            if canResend {
                Button("Resend", action: resend)
                    .buttonStyle(EdenPillButtonStyle())
                    .focusEffectDisabled()
            }
        }
        .padding(RayChat.messagePaddingV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EdenColor.hex(0xC8402A).opacity(0.07), in: .rect(cornerRadius: EdenRadius.md))
        .padding(.vertical, RayChat.messagePaddingV)
        .padding(.horizontal, RayChat.messagePaddingH)
    }
}
