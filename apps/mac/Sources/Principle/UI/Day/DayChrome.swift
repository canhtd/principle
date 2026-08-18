import DesignSystem
import SwiftUI

/// The pieces the shell is drawn from — Eden's sidebar rhythm, in SwiftUI.
///
/// Every number here is a token or a measurement from `eden-components.md`;
/// nothing on this screen picks a value of its own, so changing the package
/// changes Principle and VessaStudio together.

/// A floating side panel: `#f4f3ee`, r12, a 1 pt hairline and `shadow-sm`,
/// sitting on the canvas at an 8 pt inset (decision 2).
struct EdenPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(EdenColor.sidebar)
            .clipShape(.rect(cornerRadius: EdenRadius.md, style: .continuous))
            .edenBorder(EdenColor.black(6), radius: EdenRadius.md)
            .edenPanelShadow()
    }
}

/// Eden's `Chats` row: h26, 13.5 pt neutral-500, with the disclosure chevron
/// fading in on hover. `toggle` is `nil` for a header that names a group rather
/// than opening one.
struct SidebarSectionHeader: View {
    let title: String
    var isExpanded = true
    var toggle: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            if toggle != nil {
                Image(systemName: "chevron.down")
                    .font(EdenFont.ui(9, .semibold))
                    .foregroundStyle(EdenColor.n400)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .opacity(isHovering || !isExpanded ? 1 : 0)
                    .frame(width: 10)
            }
            Text(title)
                .font(EdenFont.ui(13.5))
                .foregroundStyle(isHovering && toggle != nil ? EdenColor.n700 : EdenColor.n500)
            Spacer(minLength: 0)
        }
        .padding(.leading, EdenMetric.sidebarInset)
        .padding(.trailing, 4)
        .frame(height: EdenMetric.groupHeaderHeight)
        .padding(.horizontal, EdenMetric.sidebarPadding)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .modifier(TapIfPresent(action: toggle))
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

/// Eden's chat/board row: h30, r12, `pl-2 pr-3`, 14 pt neutral-600, lifting to
/// neutral-900 on a `black/4%` hover.
struct SidebarRow<Content: View>: View {
    var isSelected = false
    var isMuted = false
    @ViewBuilder var content: Content

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: EdenMetric.sidebarInset) {
            content
        }
        .font(EdenFont.ui(14))
        .foregroundStyle(foreground)
        .padding(.leading, EdenMetric.sidebarInset)
        .padding(.trailing, EdenMetric.sidebarPadding)
        .frame(height: EdenMetric.rowHeight, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: .rect(cornerRadius: EdenRadius.md, style: .continuous))
        .contentShape(.rect)
        .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isMuted { return EdenColor.n400 }
        return isHovering || isSelected ? EdenColor.n900 : EdenColor.n600
    }

    private var background: Color {
        if isSelected { return EdenColor.black(6) }
        return isHovering ? EdenColor.black(4) : .clear
    }
}

/// The 36 × 36 r12 icon buttons at the panel's top right (decision 2), and the
/// smaller ones in a header.
struct EdenIconButton: View {
    let systemImage: String
    let help: String
    var isOn = false
    var size: CGFloat = EdenMetric.switcherHeight
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(EdenFont.ui(size > 30 ? 15 : 13))
                .foregroundStyle(isOn || isHovering ? EdenColor.n900 : EdenColor.n600)
                .frame(width: size, height: size)
                .background(
                    isOn ? EdenColor.black(6) : (isHovering ? EdenColor.black(4) : .clear),
                    in: .rect(cornerRadius: size > 30 ? EdenRadius.md : EdenRadius.sm, style: .continuous)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovering = $0 }
    }
}

/// The tick box — on a task it is the one control a row wears; on a category it
/// is what filters the day, and wears that category's colour.
struct TickBox: View {
    let isOn: Bool
    var color: Color
    var size: CGFloat = 15
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isOn ? color : .clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(color.opacity(isOn ? 1 : 0.5), lineWidth: 1.5)
                }
                .overlay {
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.62, weight: .bold))
                            .foregroundStyle(EdenColor.canvas)
                    }
                }
                .frame(width: size, height: size)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Done" : "Not done")
    }
}

/// `onTapGesture` only when there is something to tap — a header with no
/// disclosure must not swallow clicks.
private struct TapIfPresent: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onTapGesture(perform: action)
        } else {
            content
        }
    }
}
