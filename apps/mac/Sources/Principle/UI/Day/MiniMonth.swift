import DesignSystem
import PrincipleCore
import SwiftUI

/// The month at the bottom of column 1: how another day is picked without
/// stepping through them one at a time.
///
/// Monday-first and English, like every other date on this screen — the app's
/// copy does not follow the Mac's region.
///
/// Apple Calendar is the reference, measured off the real thing at 2x rather
/// than guessed at: an 18 pt circle on a 24 pt row, numerals at a cap height of
/// 8 pt (an 11.3 pt SF), weekday letters a step down and grey. Ours runs a
/// point larger on both counts — this panel is 260 pt wide where Calendar's
/// sidebar is 215, and the same numerals in a wider column read as smaller.
struct MiniMonth: View {
    @Bindable var journal: JournalModel

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
    private static let weekdayInitials = ["M", "T", "W", "T", "F", "S", "S"]
    /// The circle today and the selected day are drawn in, and the row it sits
    /// on — Calendar's 18/24 at this panel's scale.
    private static let circle: CGFloat = 20
    private static let cellHeight: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            header
            LazyVGrid(columns: Self.columns, spacing: 1) {
                ForEach(Array(Self.weekdayInitials.enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(EdenFont.ui(10))
                        .foregroundStyle(EdenColor.n400)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 3)
                }
                ForEach(days, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .padding(.horizontal, EdenMetric.sidebarPadding)
        .padding(.top, EdenMetric.libraryPaddingTop - 4)
    }

    private var header: some View {
        HStack(spacing: 2) {
            Text(journal.monthTitle)
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.hex(0x55524E))
            Spacer(minLength: 0)
            EdenIconButton(systemImage: "chevron.left", help: "Previous month", size: 22) {
                journal.shiftMonth(by: -1)
            }
            EdenIconButton(systemImage: "chevron.right", help: "Next month", size: 22) {
                journal.shiftMonth(by: 1)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    /// A circle, never a rounded square: Calendar's, and the one shape a date
    /// wears everywhere on the Mac.
    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: journal.day)
        let isToday = calendar.isDateInToday(date)
        let isOutside = !calendar.isDate(date, equalTo: journal.visibleMonth, toGranularity: .month)

        Button {
            journal.show(day: date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(EdenFont.ui(12, isToday || isSelected ? .semibold : .regular))
                .foregroundStyle(foreground(isSelected: isSelected, isToday: isToday, isOutside: isOutside))
                .frame(width: Self.circle, height: Self.circle)
                .background(fill(isSelected: isSelected, isToday: isToday), in: .circle)
                .frame(maxWidth: .infinity, minHeight: Self.cellHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Today keeps its red whether or not it is the day on screen — that is what
    /// makes the grid readable at a glance — and a selected other day takes the
    /// neutral circle Calendar gives it.
    private func fill(isSelected: Bool, isToday: Bool) -> Color {
        if isToday { return DayPalette.now }
        if isSelected { return EdenColor.hex(0x77746F) }
        return .clear
    }

    private func foreground(isSelected: Bool, isToday: Bool, isOutside: Bool) -> Color {
        if isToday || isSelected { return .white }
        if isOutside { return EdenColor.n300 }
        return EdenColor.hex(0x55524E)
    }

    /// Six weeks from the Monday on or before the first of the month — a fixed
    /// 42 cells, so the panel does not change height as the months go by.
    private var days: [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let parts = calendar.dateComponents([.year, .month], from: journal.visibleMonth)
        guard let first = calendar.date(from: parts) else { return [] }
        let lead = (calendar.component(.weekday, from: first) + 5) % 7
        guard let start = calendar.date(byAdding: .day, value: -lead, to: first) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
