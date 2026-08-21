import Foundation

/// How wide the two side panels are, and how that survives quitting the app
/// (#18).
///
/// Geometry only — no view here. It lives in the library rather than beside the
/// shell for one reason: a width that is clamped wrongly is a window with no
/// column 2 left in it, and that is worth a test rather than an eye.
///
/// The bounds are the spec's: the sidebar drags between 196 and 420 pt, column
/// 3 between 300 and 620. Both ends matter — under the lower bound a panel
/// clips its own rows, over the upper one it takes the day away from column 2.
public struct PanelWidths: Equatable, Sendable {
    public enum Key {
        public static let sidebar = "sidebarWidth"
        public static let detail = "detailWidth"
    }

    public static let sidebarLimits: ClosedRange<CGFloat> = 196...420
    public static let detailLimits: ClosedRange<CGFloat> = 300...620

    /// Eden's own sidebar width (`EdenMetric.sidebarWidth`), repeated here
    /// because the library does not depend on the design system. The app opens
    /// the sidebar from Eden's number rather than from this copy
    /// (`DayMetric.defaultWidths`); what keeps the copy from drifting is a test
    /// — `PanelWidthsTests` holds the two equal.
    public static let sidebarDefault: CGFloat = 260
    /// Column 3 opens wider than it used to: it now carries the principle of
    /// the day, the pane and the bookmarks rather than the pane alone.
    public static let detailDefault: CGFloat = 420

    /// Column 1's width, always inside ``sidebarLimits``.
    public var sidebar: CGFloat {
        didSet { sidebar = Self.clamp(sidebar, to: Self.sidebarLimits) }
    }

    /// Column 3's width, always inside ``detailLimits``.
    public var detail: CGFloat {
        didSet { detail = Self.clamp(detail, to: Self.detailLimits) }
    }

    public init(sidebar: CGFloat = sidebarDefault, detail: CGFloat = detailDefault) {
        // `didSet` does not run for an assignment in `init`, so both are
        // clamped by hand here.
        self.sidebar = Self.clamp(sidebar, to: Self.sidebarLimits)
        self.detail = Self.clamp(detail, to: Self.detailLimits)
    }

    /// What the last launch left behind. Anything unreadable — a missing key, a
    /// string, a 0 — falls back rather than making a panel of no width.
    ///
    /// The fallback is a parameter because the app opens the sidebar at Eden's
    /// own `sidebarWidth`, and the token for that lives in the design system,
    /// which this library does not depend on.
    public init(defaults: UserDefaults?, fallback: PanelWidths = PanelWidths()) {
        self.init(
            sidebar: Self.stored(Key.sidebar, in: defaults) ?? fallback.sidebar,
            detail: Self.stored(Key.detail, in: defaults) ?? fallback.detail
        )
    }

    /// Written at the end of a drag rather than on every frame of one: sixty
    /// writes a second buy nothing, and the value in hand is the one that is
    /// drawn either way.
    public func save(to defaults: UserDefaults?) {
        defaults?.set(Double(sidebar), forKey: Key.sidebar)
        defaults?.set(Double(detail), forKey: Key.detail)
    }

    /// A width held to its bounds, and to whatever room is actually left beside
    /// it. `room` under the lower bound is ignored: a panel narrower than its
    /// minimum clips its own rows, and at that window width the panel is a
    /// drawer anyway (``DayMetric``'s breakpoints).
    public static func clamp(
        _ value: CGFloat,
        to limits: ClosedRange<CGFloat>,
        room: CGFloat = .infinity
    ) -> CGFloat {
        let ceiling = max(limits.lowerBound, min(limits.upperBound, room))
        return min(max(value, limits.lowerBound), ceiling)
    }

    /// The pair as it is actually drawn when the window leaves only `available`
    /// points for both panels together.
    ///
    /// Column 3 gives room back first — it is the one that was made wide — and
    /// the sidebar only starts giving once column 3 is at its floor. Neither is
    /// squeezed under its minimum, and neither is ever widened: a width the
    /// person chose is not undone by a window that grew.
    public func fitted(into available: CGFloat) -> PanelWidths {
        guard sidebar + detail > available else { return self }
        let fittedDetail = max(Self.detailLimits.lowerBound, min(detail, available - sidebar))
        let fittedSidebar = max(Self.sidebarLimits.lowerBound, min(sidebar, available - fittedDetail))
        return PanelWidths(sidebar: fittedSidebar, detail: fittedDetail)
    }

    private static func stored(_ key: String, in defaults: UserDefaults?) -> CGFloat? {
        guard let defaults, defaults.object(forKey: key) != nil else { return nil }
        let value = defaults.double(forKey: key)
        // 0 is what `double(forKey:)` answers for a string, a bool or anything
        // else that is not a number — "unset", never a panel of no width.
        return value > 0 ? CGFloat(value) : nil
    }
}
