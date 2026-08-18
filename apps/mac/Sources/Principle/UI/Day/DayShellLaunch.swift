import PrincipleCore
import SwiftUI

/// The shell's half of ``LaunchHooks``: opening on a named state because a
/// script asked for one. Nothing here runs in a normal launch.
extension DayShell {
    /// Opens on a named state when a script asked for one (see ``LaunchHooks``);
    /// does nothing at all in a normal launch.
    func applyLaunchState() {
        // Here rather than at `applicationDidFinishLaunching`: the scene has no
        // window yet at that point, and macOS restores its own saved frame
        // after it — so the size is asked for once now and once more after the
        // restore has had its turn.
        LaunchHooks.applyWindowFrame()

        switch LaunchHooks.state {
        case .principles:
            ui.sidebarMode = .principles
        case .principlesPopover:
            ui.sidebarMode = .principles
            // A popover is its own window, and AppKit has nothing to hang one
            // off until the row it points at is in a window itself. Asked for
            // during this pass it is silently dropped; one turn later it opens.
            let id = PrincipleOfTheDay.principle(
                on: JournalDay(journal.day, calendar: .current),
                in: favorites.corpus
            )?.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { ui.openPrincipleID = id }
        case .taskDetail:
            ui.select(taskID: journal.timed.first?.taskID)
        case .chatFloating:
            ui.setChatMode(.floating)
        case .chatDocked:
            ui.setChatMode(.docked)
        case nil:
            break
        }
    }
}
