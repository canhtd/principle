import AppKit
import SwiftUI

/// How far the grid has been scrolled, asked of AppKit because SwiftUI will not
/// say.
///
/// The obvious version — a `GeometryReader` in the scroll content publishing a
/// preference — fires **once**, at offset zero, and then never again: not for
/// the programmatic scroll that opens the grid on the morning, and not for a
/// wheel. Measured, not assumed (`PREF offset=0.0` was the whole log after a
/// twelve-notch scroll). So the offset comes from the clip view that is
/// actually doing the scrolling, which posts a bounds notification every time
/// it moves.
///
/// Zero-sized on purpose: it is a listener living in the hierarchy, not a view
/// anybody sees.
struct ScrollOffsetProbe: NSViewRepresentable {
    /// Called on the main thread with the clip view's offset, every time it
    /// changes and once when it is attached.
    let report: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ProbeView()
        view.report = report
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ProbeView)?.report = report
    }

    final class ProbeView: NSView {
        var report: ((CGFloat) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let clip = enclosingScrollView?.contentView else { return }
            clip.postsBoundsChangedNotifications = true
            // A selector rather than a block: the block form is `@Sendable` and
            // an `NSView` cannot be captured in one.
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: clip
            )
            boundsDidChange()
        }

        @objc private func boundsDidChange() {
            guard let clip = enclosingScrollView?.contentView else { return }
            report?(clip.bounds.origin.y)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
