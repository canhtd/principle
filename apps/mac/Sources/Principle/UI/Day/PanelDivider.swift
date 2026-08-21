import AppKit
import DesignSystem
import SwiftUI

/// The seam between a panel and the day, dragged the way Finder's is (#18).
///
/// It is the canvas gap itself, not a control drawn on top of one: nothing at
/// all until the pointer crosses it, then a hairline down the middle and the
/// resize cursor. The grab area is a little wider than the gap it fills, which
/// is what makes an 8 pt seam catchable without aiming — Finder, Mail and
/// Calendar all cheat by the same couple of points.
struct PanelDivider: View {
    let help: String
    /// The hand has actually moved: the caller remembers the width it is moving
    /// from, because every later report is measured against that. Pressing the
    /// mouse down and letting it go again never gets here — a click on a seam
    /// is not a resize of nothing.
    let onBegin: () -> Void
    /// How far the pointer has travelled sideways since ``onBegin``, in points.
    let onDrag: (CGFloat) -> Void
    /// The mouse is up after a real drag: the width has settled and can be
    /// written down. Not called at all when nothing moved.
    let onEnd: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false
    /// Whether *this* divider is the one that pushed the resize cursor. Pushing
    /// twice and popping once leaves the whole window wearing it.
    @State private var pushedCursor = false

    private var isLit: Bool { isHovering || isDragging }

    var body: some View {
        Color.clear
            .frame(width: EdenMetric.sidebarInset)
            .frame(maxHeight: .infinity)
            .overlay { hairline }
            .overlay { grabArea }
            .help(help)
            // Above both columns, so the grab area's overhang is the same two
            // points on each side. The column after the divider in the row is
            // otherwise drawn — and hit-tested — over the right-hand overhang,
            // leaving a strip of 10 pt rather than 12: 6 pt to the left of the
            // divider's middle and 4 to the right.
            .zIndex(1)
            .onDisappear { setCursor(false) }
    }

    /// Inset from both ends, so it reads as a seam between two panels rather
    /// than a rule running the height of the window.
    private var hairline: some View {
        EdenColor.black(isLit ? 24 : 0)
            .frame(width: 1)
            .padding(.vertical, 14)
            .animation(.easeOut(duration: 0.15), value: isLit)
            .allowsHitTesting(false)
    }

    /// Wider than the gap and invisible. An overlay is not clipped to its
    /// parent, so the extra points hang over the two panels beside it — a
    /// couple of points of their 12 pt padding, never a row. The `zIndex` above
    /// is what keeps both halves of that overhang real.
    private var grabArea: some View {
        Color.black.opacity(0.001)
            .frame(width: DayMetric.dividerGrab)
            .contentShape(.rect)
            .onHover { hovering in
                isHovering = hovering
                setCursor(isLit)
            }
            .gesture(
                // Global, not local: the divider moves as the panel it is
                // resizing does, and a translation measured against a frame
                // that is itself sliding comes out at half the distance the
                // hand travelled.
                //
                // A resize has to be asked for, so the hand travels a little
                // first. At `minimumDistance: 0` AppKit's report of the mouse
                // going *down* was itself a change, and a plain click wrote
                // whatever width the panel happened to be drawn at over the
                // stored one. Refusing only an exactly-zero change fixed the
                // motionless click and left the point or two of tremor that
                // comes with pressing a trackpad doing the same damage.
                //
                // The distance is the gesture's own rather than a count kept
                // here: below it there is no callback at all, which is a
                // stronger guarantee than ignoring the ones that arrive.
                // Measured on the built app — a 2 pt drag produces no
                // `onChanged` and writes nothing; from 3 pt on, the panel
                // tracks the hand point for point.
                DragGesture(minimumDistance: DayMetric.dividerDragMinimum, coordinateSpace: .global)
                    .onChanged { value in
                        let dx = value.translation.width
                        if !isDragging {
                            isDragging = true
                            setCursor(true)
                            onBegin()
                        }
                        onDrag(dx)
                    }
                    .onEnded { _ in
                        let moved = isDragging
                        isDragging = false
                        if moved { onEnd() }
                        setCursor(isHovering)
                    }
            )
    }

    /// The pointer leaves during a drag as often as not — a fast drag outruns
    /// it — so the cursor is held for as long as either the hover or the drag
    /// wants it, and given back exactly once.
    private func setCursor(_ wanted: Bool) {
        guard wanted != pushedCursor else { return }
        if wanted {
            NSCursor.resizeLeftRight.push()
        } else {
            NSCursor.pop()
        }
        pushedCursor = wanted
    }
}
