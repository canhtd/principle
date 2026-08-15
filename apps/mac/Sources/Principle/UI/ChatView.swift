import PrincipleCore
import SwiftUI

/// The consultation itself: transcript, the progress line while the engine
/// works (R6), and the composer.
struct ChatView: View {
    @Bindable var model: SessionViewModel
    /// Shared with the Favorites section: the ♥ on a card writes the same file
    /// the section reads (R7).
    let favorites: FavoritesModel
    @FocusState private var composerFocused: Bool
    @State private var chapterContext: ChapterContext?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            composer
        }
        .sheet(item: $chapterContext) { ChapterContextView(context: $0) }
        .onAppear { composerFocused = true }
    }

    // MARK: - Header (AE4)

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.currentSession?.topic ?? "")
                .font(Typography.title)
                .lineSpacing(Typography.titleLineSpacing)
                .lineLimit(1)
            Spacer(minLength: 16)
            Text(model.modelLabel)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(model.messages) { message in
                        MessageRow(
                            message: message,
                            cards: model.cards(for: message),
                            isFavorite: { favorites.isFavorite($0.id) },
                            toggleFavorite: { favorites.toggle($0.id) },
                            showChapterContext: { chapterContext = ChapterContext(corpus: model.corpus, record: $0) }
                        )
                        .id(message.id)
                    }
                    if model.isShowingActiveTurn, case let streaming = model.visibleStreamingText,
                        !streaming.isEmpty
                    {
                        // Cards wait for the finished turn: the ids arrive in the
                        // trailer, at the very end.
                        MessageRow(message: ChatMessage(role: .assistant, text: streaming))
                            .id(Self.streamingAnchor)
                    }
                    if let status = statusLine {
                        StatusLine(text: status).id(Self.statusAnchor)
                    }
                    if let error = model.errorMessage {
                        ErrorBanner(message: error, canResend: model.canResend) {
                            Task { await model.resend() }
                        }
                    }
                }
                .frame(maxWidth: Typography.readingWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .onChange(of: model.streamingText) { _, _ in scroll(proxy, to: Self.streamingAnchor) }
            .onChange(of: model.messages.count) { _, _ in scroll(proxy, to: model.messages.last?.id) }
            .onChange(of: model.phase) { _, _ in scroll(proxy, to: Self.statusAnchor) }
        }
    }

    private static let streamingAnchor = "streaming"
    private static let statusAnchor = "status"

    private func scroll(_ proxy: ScrollViewProxy, to anchor: (some Hashable)?) {
        guard let anchor else { return }
        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(anchor, anchor: .bottom) }
    }

    private var statusLine: String? {
        model.isShowingActiveTurn ? model.statusLine : nil
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextEditor(text: $model.draft)
                .font(Typography.body)
                .lineSpacing(Typography.bodyLineSpacing)
                .scrollContentBackground(.hidden)
                // A fixed height, because TextEditor takes every point it is
                // offered and would otherwise eat half the transcript.
                .frame(height: 72)
                .overlay(alignment: .topLeading) {
                    if model.draft.isEmpty {
                        Text("Kể tình huống của anh…")
                            .font(Typography.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .focused($composerFocused)

            if model.canStop {
                Button("Dừng", systemImage: "stop.fill") { model.stop() }
                    .labelStyle(.titleOnly)
            }
            Button("Gửi") {
                Task { await model.send(model.draft) }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!model.canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// The progress line, per KTD7. A consultation can run for minutes, so this is
/// the only thing telling the user the app is still working.
private struct StatusLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(Typography.caption)
                .lineSpacing(Typography.captionLineSpacing)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    let canResend: Bool
    let resend: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message)
                .font(Typography.caption)
                .lineSpacing(Typography.captionLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
            if canResend {
                Button("Gửi lại", action: resend)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ChatView(model: .live(), favorites: FavoritesModel(repoURL: RepoLocation.current()))
}
