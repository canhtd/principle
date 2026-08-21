import AppKit
import Foundation

/// Two things a script needs and a person never does: put the window at an
/// exact size, and open the app already showing one particular state.
///
/// Both are read from the environment and are absent in normal use, so the app
/// Danny launches from the Dock behaves as if this file did not exist. It is
/// here because the alternative is worse: macOS restores and tiles windows
/// behind an app's back, and a screenshot taken at whatever size the window
/// server felt like is not a screenshot of a design.
enum LaunchHooks {
    /// `PRINCIPLE_WINDOW=36,50,1400,840` — origin and size in points, with the
    /// origin measured from the top left of the main screen, the way a person
    /// reading a screenshot thinks about it.
    static var windowFrame: NSRect? {
        guard let value = ProcessInfo.processInfo.environment["PRINCIPLE_WINDOW"] else { return nil }
        let parts = value.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4, let screen = NSScreen.main else { return nil }
        // AppKit's origin is the bottom left of the screen; flip it.
        let top = screen.frame.height - parts[1] - parts[3]
        return NSRect(x: parts[0], y: top, width: parts[2], height: parts[3])
    }

    /// `PRINCIPLE_STATE=principles` — which face of the shell to open on.
    static var state: State? {
        rawState.flatMap(State.init(rawValue:))
    }

    /// What was asked for, recognised or not — so a typo in a script can be
    /// told apart from a launch that asked for nothing.
    static var rawState: String? {
        ProcessInfo.processInfo.environment["PRINCIPLE_STATE"]
    }

    /// Says on stderr what a launch hook did or did not do. These hooks exist
    /// for scripts, and a script's only eyes are its log.
    static func report(_ message: String) {
        FileHandle.standardError.write(Data("PRINCIPLE_STATE: \(message)\n".utf8))
    }

    enum State: String {
        case principles
        case principlesPopover = "principles-popover"
        case taskDetail = "task-detail"
        case chatFloating = "chat-floating"
        case chatDocked = "chat-docked"
    }

    /// Sizes the window and keeps it that size for as long as a shot takes.
    ///
    /// Once is not enough: macOS restores its own saved frame — and re-applies
    /// a tiled one — at a moment nothing here can predict, so the ask is
    /// repeated until the restore has had its turn and stopped.
    ///
    /// Seven seconds of that turned out not to be long enough. With another
    /// window of the same app already open, macOS tiles the new one into the
    /// free half of the screen — and it does so *after* the last tick, at which
    /// point nothing outside the process can undo it: `setFrame` from
    /// AppleScript and from the accessibility API both report success and move
    /// nothing. A minute covers a screenshot run, and the whole hook still does
    /// nothing at all unless `PRINCIPLE_WINDOW` is set.
    @MainActor
    static func applyWindowFrame() {
        guard windowFrame != nil else { return }
        for step in 0...240 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.25) { setFrameNow() }
        }
    }

    @MainActor
    private static func setFrameNow() {
        guard let frame = windowFrame else { return }
        // The day's window, not the Settings one that ⌘, may have opened.
        for window in NSApplication.shared.windows where window.isVisible && window.title == "Principle" {
            // A window macOS restored into a full-screen Space has no frame to
            // set — and taking `.resizable` away below would strip it of the
            // only way back out, leaving a window that reports full screen for
            // the rest of the run while sitting at whatever size it was handed.
            // Leave first; the next tick sets the frame.
            if window.styleMask.contains(.fullScreen) {
                window.styleMask.insert(.resizable)
                window.toggleFullScreen(nil)
                continue
            }
            // macOS tiles windows on its own, and a tiled window keeps the
            // slot it was put in whatever frame it is handed. A window that
            // cannot be resized cannot be tiled either — and a screenshot run
            // has no use for a resize handle, so that is the way out.
            window.styleMask.remove(.resizable)
            // …and stop it saving and restoring a frame behind our back, which
            // is the other half of the argument.
            window.setFrameAutosaveName("")
            guard window.frame != frame else { continue }
            window.setFrame(frame, display: true)
            // `setFrame` takes the size and drops the origin when a second
            // window of the same app is already open: macOS cascades the new
            // one into the free half of the screen and holds it there, so the
            // window came up 1300 pt wide — our number — at an x nobody asked
            // for, with column 3 hanging off the right edge. `setFrameOrigin`
            // on its own is not cascaded, and lands.
            if window.frame.origin != frame.origin {
                window.setFrameOrigin(frame.origin)
            }
        }
    }
}
