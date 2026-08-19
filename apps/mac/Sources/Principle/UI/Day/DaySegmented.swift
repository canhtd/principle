import DesignSystem
import SwiftUI

/// The screen's one segmented control: a sunken track with the chosen segment
/// lifted out of it on a white card.
///
/// Written once and used twice — Day / Week / Month in column 2's header, and
/// Must do / Like to do in the task detail. Two controls that answer "which one
/// of these" must not each have their own idea of what chosen looks like, and
/// the detail pane's had drifted into a tint you could barely see against the
/// panel behind it.
///
/// The lift is what does the work: the selected segment is `card` white with a
/// hairline shadow under it while the track is a 5 % black well, so the
/// difference survives a glance, a screenshot, and a bad monitor.
struct DaySegmented<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    var fontSize: CGFloat = 12
    var horizontalPadding: CGFloat = 14
    let title: (Option) -> String
    let select: (Option) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button { select(option) } label: {
                    Text(title(option))
                        .font(EdenFont.ui(fontSize, isOn ? .medium : .regular))
                        .foregroundStyle(isOn ? EdenColor.textPrimary : EdenColor.hex(0x77746F))
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 5)
                        .background(isOn ? EdenColor.card : .clear, in: .rect(cornerRadius: 6, style: .continuous))
                        .shadow(color: isOn ? EdenColor.black(8) : .clear, radius: 1, y: 1)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(EdenColor.black(5), in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
        // The lifted segment is its own selected state; a system focus ring on
        // top of it reads as a second, contradictory selection.
        .focusEffectDisabled()
    }
}
