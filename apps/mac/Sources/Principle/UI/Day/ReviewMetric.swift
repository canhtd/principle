import PrincipleCore
import SwiftUI

/// The track's geometry, from the frozen prototype: 196 points tall, a 22-point
/// Dot with 6 points of air at each end, so the Dot's centre travels between 17
/// and 179 points off the floor.
enum ReviewMetric {
    static let trackHeight: CGFloat = 196
    static let dotSize: CGFloat = 22
    /// Air between the Dot and each end of the track.
    static let inset: CGFloat = 6
    /// How far the Dot's own bottom edge travels between step 1 and step 10.
    static let span = trackHeight - dotSize - inset * 2
    /// Where the number's left edge sits beside the Dot.
    static let numberInset: CGFloat = 15 + numberWidth / 2
    static let numberWidth: CGFloat = 18

    /// How far the Dot's bottom edge sits above the floor at a height.
    static func offset(ofHeight value: Int) -> CGFloat {
        inset + span * fraction(ofHeight: value)
    }

    /// The same point measured to the Dot's centre — where a tick and the number
    /// line up with it.
    static func centre(ofHeight value: Int) -> CGFloat {
        offset(ofHeight: value) + dotSize / 2
    }

    static func fraction(ofHeight value: Int) -> CGFloat {
        CGFloat(JournalDot.clamp(value) - 1) / CGFloat(JournalDot.heights.count - 1)
    }

    /// Which of the ten steps a point on the track is nearest, measured from the
    /// track's own top-left the way a gesture reports it. Past either end it is
    /// the end step rather than nothing: a pointer that ran off the top is still
    /// asking for a ten.
    static func height(atY y: CGFloat) -> Int {
        let fromFloor = (trackHeight - inset - dotSize / 2) - y
        let position = min(1, max(0, fromFloor / span))
        return JournalDot.clamp(Int((position * CGFloat(JournalDot.heights.count - 1)).rounded()) + 1)
    }
}
