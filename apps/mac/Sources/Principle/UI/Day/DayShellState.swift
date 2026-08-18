import Foundation
import Observation
import SwiftUI

/// Which axis column 2 is showing. Only Day is built (ticket #7); the other
/// three are drawn as empty states rather than hidden, because the control is
/// how Danny is told the app has a time axis at all (#9).
enum TimeAxis: String, CaseIterable, Identifiable {
    case day, week, month, year

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Which of column 1's two faces is up (decision 2).
enum SidebarMode {
    case calendar, principles
}

/// Where the Ask Ray chat is, if anywhere. Two modes like Notion AI: a panel
/// floating over the grid, or the chat docked in place of column 3 (decision 8).
enum ChatMode {
    case floating, docked
}

/// Everything on this screen that is not on disk: which panel is up, what is
/// selected, where the chat is. Kept apart from ``JournalModel`` on purpose —
/// nothing here should ever be written to the repo, and a single state object
/// makes that boundary something you can see rather than remember.
@MainActor
@Observable
final class DayShellState {
    var axis: TimeAxis = .day
    var sidebarMode: SidebarMode = .calendar
    var categoriesExpanded = true
    /// The task open in column 3, or `nil` for the day pane.
    var selectedTaskID: UUID?
    /// The category being renamed in place, the way Finder renames a file.
    var renamingCategoryID: UUID?
    /// The principle whose excerpt is open in a popover beside it.
    var openPrincipleID: String?

    /// `nil` while the chat is closed. The mode it was last used in is what the
    /// bubble reopens, for the rest of the session (decision 8).
    var chatMode: ChatMode?
    private var lastChatMode: ChatMode = .floating

    /// Side panels as overlays, under the responsive breakpoints (decision 10).
    var isSidebarDrawerOpen = false
    var isDetailDrawerOpen = false

    var isChatOpen: Bool { chatMode != nil }
    var isChatDocked: Bool { chatMode == .docked }

    func openChat() {
        chatMode = lastChatMode
    }

    func closeChat() {
        chatMode = nil
    }

    func setChatMode(_ mode: ChatMode) {
        chatMode = mode
        lastChatMode = mode
    }

    /// Opening a task's detail needs column 3, so a chat docked there floats
    /// itself out of the way rather than blocking the pane (decision 8).
    func select(taskID: UUID?) {
        if taskID != nil, isChatDocked { setChatMode(.floating) }
        selectedTaskID = taskID
    }

    /// Escape, in the order a macOS window closes things: the innermost first.
    /// Returns false when there was nothing left to close, so the key can fall
    /// through to whatever else wants it.
    @discardableResult
    func dismissTopmost() -> Bool {
        if renamingCategoryID != nil { renamingCategoryID = nil; return true }
        if openPrincipleID != nil { openPrincipleID = nil; return true }
        if isSidebarDrawerOpen || isDetailDrawerOpen {
            isSidebarDrawerOpen = false
            isDetailDrawerOpen = false
            return true
        }
        if isChatOpen, chatMode == .floating { closeChat(); return true }
        if selectedTaskID != nil { selectedTaskID = nil; return true }
        return false
    }

    /// A drawer left open must not stay "open" once the window is wide enough to
    /// dock the panel again.
    func syncDrawers(width: CGFloat) {
        if width >= DayMetric.sidebarDrawer { isSidebarDrawerOpen = false }
        if width >= DayMetric.detailDrawer { isDetailDrawerOpen = false }
    }
}
