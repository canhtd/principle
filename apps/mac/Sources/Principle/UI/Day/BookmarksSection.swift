import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 3's last section (#18): the favourited principles, grouped by which
/// book they are from, under the day's own content.
///
/// The same rows as when they were the sidebar's second face — `SidebarRow`,
/// the corpus number, the title on one line, and a click that opens the excerpt
/// beside it. Only where they sit has changed: the sidebar keeps the Categories
/// and the month, and the principles stand beside the review they are read
/// against (spec #14 Rev 6).
///
/// Not an inbox and not a backlog — the backlog is column 3's own pane.
struct BookmarksSection: View {
    @Bindable var ui: DayShellState
    let favorites: FavoritesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            PaneSectionLabel("Bookmarks")
            if favorites.isEmpty {
                PaneNote("No bookmarks yet. Bookmark a principle to keep it here.")
            } else {
                group("Life principles", records: favourites(kind: "life"))
                group("Work principles", records: favourites(kind: "work"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: favorites.refresh)
    }

    /// The group labels are a step quieter than the section's own, so the two
    /// never read as two headings doing one job.
    @ViewBuilder
    private func group(_ label: String, records: [PrincipleRecord]) -> some View {
        if !records.isEmpty {
            Text(label)
                .font(EdenFont.ui(11.5))
                .foregroundStyle(EdenColor.n400)
                .padding(.leading, EdenMetric.sidebarInset)
                .padding(.top, 2)
            VStack(spacing: 2) {
                ForEach(records) { record in
                    principleRow(record)
                }
            }
        }
    }

    private func principleRow(_ record: PrincipleRecord) -> some View {
        SidebarRow(isSelected: ui.openPrincipleID == record.id) {
            Text(record.num)
                .font(EdenFont.ui(12).monospacedDigit())
                .foregroundStyle(EdenColor.n400)
            Text(record.title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .onTapGesture { ui.openPrincipleID = record.id }
        .principleExcerpt(record: record, favorites: favorites, ui: ui)
    }

    /// Saved principles from one of the two books, newest save first. An id the
    /// corpus cannot resolve produces no row — the app never invents one.
    private func favourites(kind: String) -> [PrincipleRecord] {
        favorites.records.filter { $0.id.hasPrefix("\(kind):") }
    }
}
