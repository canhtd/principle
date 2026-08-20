import Foundation
import Observation
import PrincipleCore
import SwiftUI

/// Which axis column 2 is showing. Only Day is built (ticket #7); the other two
/// are drawn as empty states rather than hidden, because the control is how
/// Danny is told the app has a time axis at all (#9).
///
/// There is no Year: a year of days is a chart, not a grid, and the control
/// should not promise a view the app is not going to grow.
enum TimeAxis: String, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
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
    var categoriesExpanded = true
    /// The task open in column 3, or `nil` for the day pane.
    var selectedTaskID: UUID?
    /// True while column 3 is showing "Review your day" in place of the backlog.
    /// Deliberately not persisted: which of the two the column is on is a state
    /// of this sitting, not a setting.
    var isReviewing = false
    /// The track the review pane is talking about — the one last touched, which
    /// is the one wearing its number. `nil` until a track is picked.
    var reviewCategoryID: UUID?
    /// The category being renamed in place, the way Finder renames a file.
    var renamingCategoryID: UUID?
    /// True while the "New category" field the section header's "+" opens is up.
    var isAddingCategory = false
    /// The task being written, if any — see ``TaskDraft``. Nothing about it is
    /// on disk, and column 3 shows it in place of the day's own pane.
    var draft: TaskDraft?
    /// Which hour is at the vertical middle of the grid as it is scrolled right
    /// now. A new task lands there rather than at some hour nobody is looking
    /// at; the grid is the only thing that can know it, so it reports it here.
    var visibleCentreHour = Int(DayMetric.firstVisibleHour)
    /// The principle whose excerpt is open in a popover beside it.
    var openPrincipleID: String?

    /// `nil` while the chat is closed. The mode it was last used in is what the
    /// bubble reopens, for the rest of the session (decision 8).
    var chatMode: ChatMode?
    private var lastChatMode: ChatMode = .floating

    /// Side panels as overlays, under the responsive breakpoints (decision 10).
    var isSidebarDrawerOpen = false
    var isDetailDrawerOpen = false

    /// The window's content height, kept here because a popover is its own
    /// window and cannot measure the one it points at.
    var windowHeight: CGFloat = 0

    /// How tall the excerpt popover may grow before it starts scrolling.
    ///
    /// A principle's body runs from one line to a page and a half, and the
    /// popover shows all of it — but not by growing past the window it is
    /// pinned inside. Sixty per cent leaves the row that was clicked visible
    /// above or below it, which is the point of a popover rather than a sheet.
    var excerptMaxHeight: CGFloat {
        let sane = windowHeight > 0 ? windowHeight : 800
        return max(240, sane * 0.6)
    }

    /// Opens a draft at the hour in the middle of the grid, an hour long — the
    /// two defaults Apple Calendar uses for a new event made from the toolbar
    /// rather than by dragging.
    func startDraft(categoryID: UUID?) {
        selectedTaskID = nil
        isReviewing = false
        if isChatDocked { setChatMode(.floating) }
        draft = TaskDraft(
            categoryID: categoryID,
            schedule: TaskSchedule(startMinute: visibleCentreHour * 60)
        )
    }

    /// Where the grid is: called as it scrolls, and only ever with the hour, so
    /// a drag of the scroller writes state a handful of times rather than once
    /// a frame.
    func noteGridCentre(offsetY: CGFloat, viewportHeight: CGFloat) {
        guard viewportHeight > 0 else { return }
        let centre = offsetY + viewportHeight / 2 - DayMetric.topInset
        let hour = Int((Double(DayMetric.minute(atY: centre)) / 60).rounded())
        let clamped = min(23, max(0, hour))
        if clamped != visibleCentreHour { visibleCentreHour = clamped }
    }

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
        // A draft and a selection are two answers to the same question.
        // So are a task and the review: both want the whole column, and the
        // header's own word for what is up has to keep being true.
        if taskID != nil {
            draft = nil
            isReviewing = false
        }
    }

    /// The way into the review and back out again — one control, in the header's
    /// free left cell, on every day rather than after five o'clock.
    func toggleReview() {
        isReviewing.toggle()
        if isReviewing {
            selectedTaskID = nil
            draft = nil
        }
    }

    /// Escape, in the order a macOS window closes things: the innermost first.
    /// Returns false when there was nothing left to close, so the key can fall
    /// through to whatever else wants it.
    @discardableResult
    func dismissTopmost() -> Bool {
        if renamingCategoryID != nil { renamingCategoryID = nil; return true }
        if isAddingCategory { isAddingCategory = false; return true }
        // Escape on a draft throws it away — that is the whole bargain of a
        // draft, and it must beat the drawers and the chat to the key.
        if draft != nil { draft = nil; return true }
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
