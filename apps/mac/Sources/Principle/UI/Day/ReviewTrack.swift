import DesignSystem
import PrincipleCore
import SwiftUI

/// One Category's track: ten steps, its Dot, and its name under them.
///
/// Press anywhere on the track and the Dot goes to the nearest step; drag and it
/// follows, snapping as it goes, with the number beside it while it is in hand.
/// Press the step the Dot already stands on and the judgement is taken back —
/// the Dot returns to the muted midpoint, which is the drawing of "unset" and
/// never a five.
struct ReviewTrack: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let category: JournalCategory
    /// The rightmost track has no room for its number on the right.
    var numberOnLeft = false

    @State private var isHovering = false
    /// What the press started from — `nil` between presses. It is what tells a
    /// click that sets from a click that clears.
    @State private var press: Press?

    /// Where the Dot stood when the press began, and whether the pointer has
    /// moved since. A press that neither moved nor changed the height is the
    /// one gesture that means "take this back".
    private struct Press {
        let had: Int?
        var moved = false
    }

    private var height: Int? { journal.dotHeight(for: category.id) }
    private var isSetting: Bool { press != nil }
    /// The number rides beside the Dot only while its track is the one in hand —
    /// or the one last touched, which is the track the pane is talking about.
    private var showsNumber: Bool { height != nil && (isSetting || ui.reviewCategoryID == category.id) }

    var body: some View {
        VStack(spacing: 0) {
            track
            Text(category.name)
                .font(EdenFont.ui(11.5))
                .foregroundStyle(ui.reviewCategoryID == category.id ? EdenColor.n700 : EdenColor.hex(0x77746F))
                .lineLimit(1)
                .padding(.top, 7)
                .padding(.horizontal, 2)
                .contentShape(.rect)
                .onTapGesture { ui.reviewCategoryID = category.id }
        }
        .frame(maxWidth: .infinity)
    }

    private var track: some View {
        ZStack(alignment: .bottom) {
            rail
            if isHovering || isSetting { ticks }
            if let value = height, showsNumber { number(value) }
            dot
        }
        .frame(maxWidth: .infinity)
        .frame(height: ReviewMetric.trackHeight)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { EdenColor.black(10).frame(height: 1) }
        .onHover { isHovering = $0 }
        // The Bar is one hover away rather than printed under every track, so
        // the pane stays quiet (story 9). Picked, the same sentence reads in
        // full under the chart.
        .help(category.bar ?? "No bar set for \(category.name)")
        .gesture(setting)
    }

    private var rail: some View {
        Capsule()
            .fill(EdenColor.black(isHovering || isSetting ? 11 : 7))
            .frame(width: 4)
            .padding(.vertical, 10)
    }

    /// The ten steps, shown only while the track is under the pointer or in
    /// hand: a track that always wore its ruler would read as a measurement.
    private var ticks: some View {
        ForEach(JournalDot.heights, id: \.self) { step in
            Circle()
                .fill(EdenColor.black(20))
                .frame(width: 2, height: 2)
                .offset(y: -(ReviewMetric.centre(ofHeight: step) - 1))
        }
    }

    private var dot: some View {
        let isSet = height != nil
        return Text(initial)
            .font(EdenFont.ui(11, .semibold))
            .foregroundStyle(isSet ? .white : (isHovering ? EdenColor.n600 : EdenColor.n400))
            .frame(width: ReviewMetric.dotSize, height: ReviewMetric.dotSize)
            .background(Circle().fill(fill))
            // A hairline inside the muted dot, so it reads as an empty slot
            // rather than a grey judgement.
            .overlay { if !isSet { Circle().strokeBorder(EdenColor.black(7), lineWidth: 1) } }
            // The ring is the panel's own colour: it cuts the rail behind the
            // Dot rather than drawing anything of its own.
            .overlay {
                Circle()
                    .strokeBorder(EdenColor.sidebar, lineWidth: 2)
                    .frame(width: ReviewMetric.dotSize + 4, height: ReviewMetric.dotSize + 4)
            }
            .scaleEffect(isSetting ? 1.1 : 1)
            .offset(y: -ReviewMetric.offset(ofHeight: height ?? JournalDot.restingHeight))
            // In hand the Dot is under the pointer, not chasing it.
            .animation(isSetting ? nil : .easeOut(duration: 0.12), value: height)
    }

    private var fill: Color {
        guard height != nil else { return isHovering ? EdenColor.n300 : EdenColor.n200 }
        return DayPalette.color(category)
    }

    private var initial: String { category.name.first.map(String.init) ?? "?" }

    private func number(_ value: Int) -> some View {
        Text("\(value)")
            .font(EdenFont.ui(12, .medium))
            .monospacedDigit()
            .foregroundStyle(EdenColor.textPrimary)
            .frame(width: ReviewMetric.numberWidth, alignment: numberOnLeft ? .trailing : .leading)
            .offset(
                x: numberOnLeft ? -ReviewMetric.numberInset : ReviewMetric.numberInset,
                y: -(ReviewMetric.centre(ofHeight: value) - 6)
            )
            .allowsHitTesting(false)
    }

    /// One gesture for the press, the drag and the release: on macOS a click is
    /// a drag of zero distance, and treating them as two would put a Dot on a
    /// step the pointer only passed over.
    private var setting: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if press == nil {
                    press = Press(had: height)
                    ui.reviewCategoryID = category.id
                }
                if abs(value.translation.height) > 3 || abs(value.translation.width) > 3 {
                    press?.moved = true
                }
                journal.setDot(ReviewMetric.height(atY: value.location.y), for: category.id)
            }
            .onEnded { value in
                let step = ReviewMetric.height(atY: value.location.y)
                let started = press ?? Press(had: height)
                press = nil
                ui.reviewCategoryID = category.id
                if !started.moved, started.had == step {
                    journal.clearDot(for: category.id)
                } else {
                    journal.setDot(step, for: category.id)
                }
            }
    }
}
