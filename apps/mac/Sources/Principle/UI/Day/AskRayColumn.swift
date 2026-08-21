import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 3 with Ask Ray docked in it (decision 8, #18).
///
/// Docking the chat swaps the *pane*, not the column. #18 puts the principle of
/// the day at the top of column 3 and the bookmarks at the bottom of it in every
/// mode, and a chat that threw both away would be the one screen where the day's
/// principle is not on the day — which is the habit the column exists to build.
///
/// The chat takes whatever height the two ends leave, because it is the thing
/// being used: the principle is one card, the bookmarks stop after a few rows
/// and scroll inside themselves, and everything else goes to the thread.
struct AskRayColumn: View {
    @Bindable var journal: JournalModel
    @Bindable var session: SessionViewModel
    let favorites: FavoritesModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PrincipleOfTheDaySection(journal: journal, favorites: favorites, ui: ui)

            AskRayPanel(session: session, favorites: favorites, ui: ui, isDocked: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bookmarks
        }
        .padding(.horizontal, EdenMetric.sidebarPadding)
        .padding(.vertical, EdenMetric.libraryPaddingTop - 4)
    }

    /// Capped rather than free: the bookmarks are the column's foot, and a long
    /// list of them must not push the thread off the screen.
    ///
    /// The cap is the whole mechanism, so nothing may be allowed to talk the
    /// scroll view out of it. `fixedSize(vertical:)` does exactly that — it
    /// proposes no height at all, so the scroll view answers with its
    /// *content's* height and the cap above it never binds, which puts a long
    /// list through the foot of the panel. Left greedy inside `0...cap`
    /// instead, the scroll view takes the cap when there is room for it and
    /// less when there is not, and `VStack` hands it its share before the
    /// thread's because it is the less flexible of the two.
    ///
    /// An empty list is the one case with no scrolling to do, and it says its
    /// single line without reserving the cap for it.
    @ViewBuilder
    private var bookmarks: some View {
        if favorites.isEmpty {
            BookmarksSection(ui: ui, favorites: favorites)
        } else {
            ScrollView {
                BookmarksSection(ui: ui, favorites: favorites)
            }
            .scrollIndicators(.never)
            // The list is read from the top or it is not read at all. Without
            // this it opened part-way down a long one — the heading and the
            // first rows already scrolled past — because the rows arrive from
            // disk after the scroll view has laid out, and it keeps the offset
            // it had rather than following the content back up.
            .defaultScrollAnchor(.top)
            .frame(maxHeight: DayMetric.chatColumnBookmarks)
        }
    }
}
