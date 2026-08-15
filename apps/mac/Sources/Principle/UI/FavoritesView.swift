import PrincipleCore
import SwiftUI

/// The principles kept from past consultations (R7), newest save first.
///
/// The same cards as in the chat, so a saved principle reads exactly the way it
/// did when Ray cited it — including the ♥ that takes it back off the list.
struct FavoritesView: View {
    let favorites: FavoritesModel
    /// Sends the reader back to the chat from the empty state.
    var openChat: () -> Void = {}

    @State private var chapterContext: ChapterContext?

    var body: some View {
        Group {
            if favorites.isEmpty {
                empty
            } else {
                list
            }
        }
        .sheet(item: $chapterContext) { ChapterContextView(context: $0) }
        // A terminal session may have appended to favorites.jsonl while the app
        // sat on the chat tab.
        .onAppear { favorites.refresh() }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PrincipleCardList(
                    principles: favorites.records,
                    isFavorite: { favorites.isFavorite($0.id) },
                    toggleFavorite: { favorites.toggle($0.id) },
                    showChapterContext: { chapterContext = ChapterContext(corpus: favorites.corpus, record: $0) }
                )
                notices
            }
            .frame(maxWidth: Typography.readingWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(20)
        }
    }

    @ViewBuilder
    private var notices: some View {
        // AE2: an id the corpus cannot resolve is reported, never drawn as a
        // card with invented text.
        if !favorites.unresolvedIDs.isEmpty {
            Label(
                "\(favorites.unresolvedIDs.count) nguyên tắc đã lưu không tra được trong corpus",
                systemImage: "exclamationmark.triangle"
            )
            .font(Typography.caption)
            .foregroundStyle(.secondary)
        }
        if let error = favorites.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label(FavoritesModel.emptyTitle, systemImage: AppSection.favorites.systemImage)
        } description: {
            Text(FavoritesModel.emptyHint)
        } actions: {
            Button("Mở trò chuyện", action: openChat)
        }
    }
}

#Preview {
    FavoritesView(favorites: FavoritesModel(repoURL: RepoLocation.current()))
}
