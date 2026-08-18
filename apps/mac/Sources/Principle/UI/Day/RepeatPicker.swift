import DesignSystem
import PrincipleCore
import SwiftUI

/// The four kinds of repeat and no more (spec #6). The weekday row appears only
/// for the two kinds that need one, so the field is one line until it isn't.
struct RepeatPicker: View {
    let rule: RepeatRule
    let change: (RepeatRule) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EdenMetric.sidebarInset) {
            Picker("Repeat", selection: kindBinding) {
                ForEach(RepeatKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .labelsHidden()
            .font(EdenFont.ui(13))

            switch rule {
            case .weekdays(let days):
                weekdayRow(isOn: { days.contains($0) }) { day in
                    change(.weekdays(days.symmetricDifference([day])))
                }
            case .weekly(let chosen):
                weekdayRow(isOn: { $0 == chosen }) { change(.weekly($0)) }
            case .none, .daily:
                EmptyView()
            }
        }
    }

    private var kindBinding: Binding<RepeatKind> {
        Binding(
            get: { RepeatKind(rule) },
            set: { change($0.rule(keeping: rule)) }
        )
    }

    private func weekdayRow(isOn: @escaping (Weekday) -> Bool, toggle: @escaping (Weekday) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let on = isOn(day)
                Button { toggle(day) } label: {
                    Text(day.initial)
                        .font(EdenFont.ui(11.5, on ? .medium : .regular))
                        .foregroundStyle(on ? EdenColor.primary : EdenColor.hex(0x77746F))
                        .frame(width: 30, height: 26)
                        .background(
                            on ? EdenColor.primary5 : .clear,
                            in: .rect(cornerRadius: EdenRadius.sm, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: EdenRadius.sm, style: .continuous)
                                .strokeBorder(on ? .clear : EdenColor.black(10))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The four choices as the picker offers them — the rule minus its weekdays, so
/// switching kind and switching day are two separate acts.
enum RepeatKind: String, CaseIterable, Identifiable {
    case none, daily, weekdays, weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .daily: "Every day"
        case .weekdays: "Weekdays"
        case .weekly: "Once a week"
        }
    }

    init(_ rule: RepeatRule) {
        switch rule {
        case .none: self = .none
        case .daily: self = .daily
        case .weekdays: self = .weekdays
        case .weekly: self = .weekly
        }
    }

    /// Picking a kind keeps whatever days the old rule named, so flipping
    /// through the list and back does not wipe the week that was set.
    func rule(keeping previous: RepeatRule) -> RepeatRule {
        switch self {
        case .none: .none
        case .daily: .daily
        // Mon–Fri is what "Weekdays" means to everyone before anything is
        // ticked; an empty set would be a rule that names no day at all.
        case .weekdays: .weekdays(previous.chosenDays ?? Weekday.workingWeek)
        case .weekly: .weekly(previous.chosenDays?.min { $0.weekOrder < $1.weekOrder } ?? .monday)
        }
    }
}

extension RepeatRule {
    var chosenDays: Set<Weekday>? {
        switch self {
        case .weekdays(let days): days.isEmpty ? nil : days
        case .weekly(let day): [day]
        case .none, .daily: nil
        }
    }
}

extension Weekday {
    /// `M`, `T`, `W` — the letter the toggle wears.
    var initial: String { String(label.prefix(1)) }

    var label: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }
}
