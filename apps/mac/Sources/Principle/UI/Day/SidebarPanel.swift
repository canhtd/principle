import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 1. Two faces behind one pair of icon buttons (decision 2): the
/// calendar — what the day is filtered by and how another day is picked — and
/// the principles.
///
/// No app name and no title bar in it: the panel is content from its first
/// pixel, which is what makes the window read as a document rather than a tool.
/// The traffic lights sit *on* that first pixel — `WindowChrome` puts them 12 pt
/// inside the panel's own top-left corner — so the panel opens with enough room
/// above its first control for them to land on its surface rather than on a
/// strip of canvas above it.
struct SidebarPanel: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let favorites: FavoritesModel
    /// Native full screen has no lights to clear, so the panel keeps only its
    /// own top pad and gives the rest back.
    var isFullScreen = false

    private var topInset: CGFloat {
        isFullScreen ? EdenMetric.sidebarTopInsetFullScreen : EdenMetric.sidebarTopInset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            modes
            switch ui.sidebarMode {
            case .calendar:
                CategoryList(journal: journal, ui: ui)
                Spacer(minLength: 0)
                MiniMonth(journal: journal)
            case .principles:
                PrinciplesPanel(journal: journal, ui: ui, favorites: favorites)
            }
            settingsRow
        }
        .padding(.top, topInset)
        .padding(.bottom, EdenMetric.sidebarPadding)
    }

    /// Calendar / Principles as 36 × 36 r12 Eden icon buttons, at the panel's
    /// right.
    private var modes: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            EdenIconButton(
                systemImage: "calendar",
                help: "Calendar",
                isOn: ui.sidebarMode == .calendar
            ) { ui.sidebarMode = .calendar }
            EdenIconButton(
                systemImage: ui.sidebarMode == .principles ? "bookmark.fill" : "bookmark",
                help: "Principles",
                isOn: ui.sidebarMode == .principles
            ) { ui.sidebarMode = .principles }
        }
        .padding(.horizontal, EdenMetric.sidebarPadding)
        .padding(.bottom, 2)
    }

    /// Settings and Profile stay reachable — ⌘, opens the same window, but a
    /// keyboard shortcut is not a way to find something for the first time.
    private var settingsRow: some View {
        HStack(spacing: 2) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
                    .font(EdenFont.ui(13))
                    .foregroundStyle(EdenColor.n500)
                    .frame(width: EdenMetric.rowHeight, height: EdenMetric.rowHeight)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Settings")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, EdenMetric.sidebarInset)
        .padding(.top, EdenMetric.sidebarInset)
    }
}
