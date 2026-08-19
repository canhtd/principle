import AppKit
import DesignSystem
import SwiftUI

/// Where the window's traffic lights sit, and whether the window is in native
/// full screen.
///
/// The shell has no title bar (`PrincipleApp` asks for `.hiddenTitleBar`), so
/// the lights land on whatever is drawn at the window's top left. AppKit puts
/// them 9 pt in — 1 pt inside a panel that is itself inset 8, which reads as
/// three dots balanced on the panel's corner. Eden and Notion put them *inside*
/// the panel with room around them, so this moves them to
/// `sidebarInset + trafficLightInset` on both axes.
///
/// The buttons keep their place in the window's own title-bar view rather than
/// being re-parented into the content view: AppKit hands that view to the
/// full-screen overlay title bar, and a button whose superview is somewhere
/// else never comes back. The title-bar view is only 32 pt tall, though, and a
/// view is not hit-tested outside its superview's bounds — so it has to grow
/// before the lights move down into the space. AppKit resets both whenever it
/// lays the window out, which is why this re-applies rather than running once.
struct WindowChrome: NSViewRepresentable {
    /// Native full screen has no traffic lights to clear, so column 1 gives the
    /// room back.
    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> NSView {
        let view = TrafficLightHost()
        view.onFullScreenChange = { full in
            // Never during a view update: this arrives from a notification and
            // from `viewDidMoveToWindow`, either of which can land inside
            // SwiftUI's own pass.
            DispatchQueue.main.async { isFullScreen = full }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Places the traffic lights inside the sidebar panel and reports the
    /// full-screen state back.
    func edenWindowChrome(isFullScreen: Binding<Bool>) -> some View {
        background(WindowChrome(isFullScreen: isFullScreen).frame(width: 0, height: 0))
    }
}

/// The zero-sized view that exists only to reach the `NSWindow` behind the scene.
private final class TrafficLightHost: NSView {
    var onFullScreenChange: (Bool) -> Void = { _ in }

    /// `nonisolated(unsafe)` only so `deinit` — which Swift 6 does not isolate
    /// — can hand the tokens back. Every write happens on the main actor.
    private nonisolated(unsafe) var observers: [NSObjectProtocol] = []
    private var isApplying = false

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }
        let centre = NotificationCenter.default
        for name: Notification.Name in [NSWindow.didResizeNotification,
                                        NSWindow.didEnterFullScreenNotification,
                                        NSWindow.didExitFullScreenNotification,
                                        NSWindow.didBecomeKeyNotification] {
            observers.append(centre.addObserver(forName: name, object: window,
                                                queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.apply() }
            })
        }
        // AppKit lays the lights out again whenever it feels like it; the
        // button itself is what says so.
        if let close = window.standardWindowButton(.closeButton) {
            close.postsFrameChangedNotifications = true
            observers.append(centre.addObserver(forName: NSView.frameDidChangeNotification,
                                                object: close, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.apply() }
            })
        }
        apply()
    }

    @MainActor
    private func apply() {
        guard !isApplying, let window else { return }
        let full = window.styleMask.contains(.fullScreen)
        onFullScreenChange(full)
        // In full screen the lights belong to the overlay title bar, which
        // slides in over the window. Nothing here has any business moving them.
        guard !full,
              let close = window.standardWindowButton(.closeButton),
              let minimise = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let titlebar = close.superview
        else { return }
        isApplying = true
        defer { isApplying = false }

        let inset = EdenMetric.sidebarInset + EdenMetric.trafficLightInset
        grow(titlebar, toFit: inset + close.frame.height)
        // Whatever the system's own gap between the three is, kept.
        let spacing = minimise.frame.minX - close.frame.maxX
        let bottom = window.frame.height - inset - close.frame.height
        var x = inset
        for button in [close, minimise, zoom] {
            let origin = titlebar.convert(NSPoint(x: x, y: bottom), from: nil)
            if button.frame.origin != origin { button.setFrameOrigin(origin) }
            x += button.frame.width + spacing
        }
    }

    /// A view is not hit-tested outside its superview's bounds, so the title
    /// bar has to be at least as tall as the lights now reach. Its container
    /// keeps its top edge against the window's.
    private func grow(_ titlebar: NSView, toFit height: CGFloat) {
        let wanted = height + EdenMetric.sidebarInset / 2
        guard let container = titlebar.superview, titlebar.frame.height < wanted else { return }
        let extra = wanted - titlebar.frame.height
        container.setFrameSize(NSSize(width: container.frame.width,
                                      height: container.frame.height + extra))
        container.setFrameOrigin(NSPoint(x: container.frame.minX,
                                         y: container.frame.minY - extra))
        titlebar.setFrameSize(NSSize(width: titlebar.frame.width,
                                     height: titlebar.frame.height + extra))
    }
}
