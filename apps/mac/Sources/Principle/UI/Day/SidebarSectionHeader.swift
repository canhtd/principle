import DesignSystem
import SwiftUI

/// Eden's `Chats` row with macOS's sidebar rhythm on top of it: the name at the
/// left, and at the right edge the "+" that makes a new one and the disclosure
/// chevron.
///
/// Both controls fade in on hover while the section is open and stay put once it
/// is closed — a collapsed group with nothing beside it gives no sign there is
/// anything behind it. That is Finder's and Calendar's rule; Eden has it for the
/// chevron alone, and the "+" follows the chevron rather than inventing a
/// second rhythm.
struct SidebarSectionHeader: View {
    let title: String
    var isExpanded = true
    var toggle: (() -> Void)?
    /// The "+" beside the chevron, absent on a header naming a group nothing can
    /// be added to.
    var add: (() -> Void)?
    var addHelp = "New item"

    @State private var isHovering = false

    private var showsControls: Bool { isHovering || !isExpanded }

    var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .font(EdenFont.ui(13.5))
                .foregroundStyle(isHovering && toggle != nil ? EdenColor.n700 : EdenColor.n500)
            Spacer(minLength: 4)
            if let add {
                control(systemImage: "plus", help: addHelp, action: add)
            }
            if let toggle {
                control(
                    systemImage: "chevron.down",
                    help: isExpanded ? "Collapse \(title)" : "Expand \(title)",
                    rotation: isExpanded ? 0 : -90,
                    action: toggle
                )
            }
        }
        .padding(.leading, EdenMetric.sidebarInset)
        .padding(.trailing, 2)
        .frame(height: EdenMetric.groupHeaderHeight)
        .padding(.horizontal, EdenMetric.sidebarPadding)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .modifier(TapIfPresent(action: toggle))
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isExpanded)
    }

    /// A 9 pt glyph in an 18 pt target: small enough to read as chrome, big
    /// enough to hit without aiming.
    private func control(
        systemImage: String,
        help: String,
        rotation: Double = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(EdenFont.ui(9, .semibold))
                .foregroundStyle(EdenColor.n400)
                .rotationEffect(.degrees(rotation))
                .frame(width: 18, height: 18)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
        .focusEffectDisabled()
        .opacity(showsControls ? 1 : 0)
        // Invisible is not the same as absent: a control that keeps its slot
        // stops the title sliding sideways as the pointer crosses the header.
        .allowsHitTesting(showsControls)
    }
}

/// `onTapGesture` only when there is something to tap — a header with no
/// disclosure must not swallow clicks.
struct TapIfPresent: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onTapGesture(perform: action)
        } else {
            content
        }
    }
}
