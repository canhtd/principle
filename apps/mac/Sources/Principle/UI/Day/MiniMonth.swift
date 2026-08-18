import DesignSystem
import PrincipleCore
import SwiftUI

/// The month at the bottom of column 1: how another day is picked without
/// stepping through them one at a time.
///
/// Monday-first and English, like every other date on this screen — the app's
/// copy does not follow the Mac's region.
struct MiniMonth: View {
    @Bindable var journal: JournalModel

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
    private static let weekdayInitials = ["M", "T", "W", "T", "F", "S", "S"]

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
                .font(EdenFont.ui(11, isToday ? .semibold : .regular))
                .foregroundStyle(foreground(isSelected: isSelected, isToday: isToday, isOutside: isOutside))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    isSelected ? EdenColor.primary80 : .clear,
                    in: .rect(cornerRadius: 6, style: .continuous)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func foreground(isSelected: Bool, isToday: Bool, isOutside: Bool) -> Color {
        if isSelected { return .white }
        if isOutside { return EdenColor.n300 }
        if isToday { return EdenColor.primary }
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
