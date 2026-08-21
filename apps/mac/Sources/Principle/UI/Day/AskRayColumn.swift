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

    /// How tall the bookmarks would be if nothing capped them. Starts at the
    /// cap so the first frame is drawn at a sane height rather than at nothing,
    /// and is corrected the moment the list has been measured.
    @State private var listHeight: CGFloat = DayMetric.chatColumnBookmarks

    var body: some View {
        // 20, the gap ``DetailPanel`` puts between the same column's sections.
        // It is one column in two modes, and docking the chat must not be a
        // change of rhythm.
        VStack(alignment: .leading, spacing: 20) {
            PrincipleOfTheDaySection(journal: journal, favorites: favorites, ui: ui)

            AskRayPanel(session: session, favorites: favorites, ui: ui, isDocked: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bookmarks
        }
        .padding(.horizontal, EdenMetric.sidebarPadding)
        .padding(.vertical, EdenMetric.libraryPaddingTop - 4)
    }

    /// Capped rather than free: the bookmarks are the column's foot, and a long
    /// list of them must not push the thread off the screen. But a cap is a
    /// ceiling and must not become a floor — one bookmark is one row, and 190
    /// points of empty scroll view under it is 190 points taken off the thread
    /// for nothing.
    ///
    /// So the height is `min(list, cap)`, measured rather than negotiated. Both
    /// of the shorter spellings are wrong here, in opposite directions, and
    /// both were tried:
    ///
    /// - `frame(maxHeight:)` is not a ceiling on a *request*, it is a ceiling
    ///   on a greedy view: a `max` frame takes the height it is offered and
    ///   clamps that, which is exactly why `frame(maxWidth: .infinity)` is how
    ///   one fills a row. One bookmark still reserved all 190 and sat centred
    ///   in the empty half of it.
    /// - `fixedSize(vertical:)` proposes no height at all, the scroll view
    ///   answers with its content's, and the cap never binds — a long list ran
    ///   out through the foot of the panel.
    ///
    /// `frame(height:)` is neither: it is the exact number, so a short list
    /// takes its own height and gives the rest to the thread, and a long one
    /// stops at the cap and scrolls. The measurement happens inside the scroll
    /// view, which proposes no height down its own axis — so what is read there
    /// is the list's full height, not the window it is being shown through.
    private var bookmarks: some View {
        ScrollView {
            BookmarksSection(ui: ui, favorites: favorites)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: proxy.size.height, initial: true) { _, height in
                                listHeight = height
                            }
                    }
                }
        }
        .scrollIndicators(.never)
        // The list is read from the top or it is not read at all. Without this
        // it opened part-way down a long one — the heading and the first rows
        // already scrolled past — because the rows arrive from disk after the
        // scroll view has laid out, and it keeps the offset it had rather than
        // following the content back up.
        //
        // The trade taken knowingly: this also snaps back to the top when the
        // list changes under a reader who had scrolled down. Bookmarks change
        // when Danny bookmarks something, which is rare and is not something he
        // does from inside this list.
        .defaultScrollAnchor(.top)
        .frame(height: min(listHeight, DayMetric.chatColumnBookmarks))
    }
}
