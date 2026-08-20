import DesignSystem
import SwiftUI

/// The label above a section of column 3 — "Principle of the day", "Review your
/// day", "Day note", "Bookmarks".
///
/// One quiet 12 pt line rather than the sidebar's `SidebarSectionHeader`: column
/// 3 stacks four sections now (spec #14 Rev 6), and they only read as one rhythm
/// if every label is the same label.
struct PaneSectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(EdenFont.ui(12))
            .foregroundStyle(EdenColor.hex(0x77746F))
    }
}

/// What a section says when it has nothing to show. Never a stand-in for the
/// content — it says plainly that there is none.
struct PaneNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(EdenFont.ui(12))
            .foregroundStyle(EdenColor.n400)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
