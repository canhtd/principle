import DesignSystem
import SwiftUI

/// The two other places work is going to come from, named but not built:
/// project tickets out of GitHub (#3) and the decision journal (#2).
///
/// They are here rather than nowhere because the backlog otherwise reads as the
/// whole list, and it is not — a source Danny is waiting for is a different
/// thing from a source that does not exist. Deferred, so the rows are inert: no
/// hover lift, no click, nothing to press by accident. The help text is where
/// the promise is written down, which keeps the list itself quiet.
struct LaterSection: View {
    /// Aligned with the titles above rather than with the group label: the tick
    /// square a backlog row wears is 9 pt in an 8 pt gutter with 8 pt after it,
    /// and these rows belong in the same column of text without borrowing the
    /// square, which would say they can be filtered.
    private static let titleInset = EdenMetric.sidebarInset * 2 + 9

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Later")
                .font(EdenFont.ui(11.5))
                .foregroundStyle(EdenColor.n400)
            VStack(spacing: 0) {
                row("GitHub tickets", help: "Project tickets will arrive here once GitHub is connected.")
                row("Decision journal", help: "Decisions waiting to be rated will arrive here.")
            }
            .padding(.horizontal, -EdenMetric.sidebarInset)
        }
        .padding(.top, 9)
    }

    private func row(_ title: String, help: String) -> some View {
        Text(title)
            .font(EdenFont.ui(14))
            .foregroundStyle(EdenColor.n400)
            .lineLimit(1)
            .padding(.leading, Self.titleInset)
            .padding(.trailing, EdenMetric.sidebarPadding)
            .frame(height: EdenMetric.rowHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .help(help)
    }
}
