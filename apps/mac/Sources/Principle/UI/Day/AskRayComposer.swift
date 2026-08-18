import DesignSystem
import PrincipleCore
import SwiftUI

/// Eden's composer: a rounded pill holding the question on its own row and the
/// controls on a second one underneath.
///
/// Two rows rather than one, because a question to Ray is a sentence or three,
/// not a search term — the text gets the full width of the pill and the buttons
/// never squeeze it.
struct AskRayComposer: View {
    @Bindable var model: SessionViewModel
    /// Sending is the panel's business: the first question of a consultation has
    /// to open one before it can be sent.
    let send: () -> Void
    let canSend: Bool

    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            field
            controls
        }
        .padding(.top, RayChat.pillRowPaddingTop)
        .padding(.horizontal, RayChat.pillRowPaddingH)
        .padding(.bottom, RayChat.pillRowPaddingBottom)
        .background(EdenColor.white(60), in: .rect(cornerRadius: RayChat.pillRadius, style: .continuous))
        .edenBorder(RayChat.warm(isFocused || isHovering ? 22 : 9), radius: RayChat.pillRadius)
        .animation(.easeOut(duration: 0.2), value: isFocused)
        .onHover { isHovering = $0 }
        // The whole pill is the text field's hit area, the way a composer reads.
        .contentShape(.rect(cornerRadius: RayChat.pillRadius))
        .onTapGesture { isFocused = true }
        .padding(.horizontal, RayChat.composerInset)
        .padding(.bottom, RayChat.composerBottom)
    }

    private var field: some View {
        TextField("Ask Ray about today", text: $model.draft, axis: .vertical)
            .textFieldStyle(.plain)
            .font(EdenFont.ui(RayChat.composerTextSize))
            .lineSpacing(RayChat.composerTextSize * (RayChat.composerTextLineHeight - 1))
            .foregroundStyle(RayChat.ink)
            .lineLimit(1...6)
            .focused($isFocused)
            .focusEffectDisabled()
            .padding(.horizontal, RayChat.pillRowGap)
            .frame(minHeight: RayChat.composerTextMinHeight, alignment: .topLeading)
            // Enter sends, Shift-Enter is a new line — the axis:.vertical field
            // would otherwise only ever grow.
            .onSubmit(send)
    }

    private var controls: some View {
        HStack(spacing: RayChat.partGap) {
            RayIconButton(systemImage: "plus", help: "Add context") {}
                .disabled(true)
                .opacity(0.5)
            Spacer(minLength: 0)
            if model.canStop {
                RayIconButton(systemImage: "stop.fill", help: "Stop") { model.stop() }
            }
            sendButton
        }
    }

    /// The one filled control in the pane, so the eye finds it without looking.
    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up")
                .font(EdenFont.ui(RayChat.iconGlyph - 3, .medium))
                .foregroundStyle(canSend ? EdenColor.primary5 : EdenColor.n500)
                .frame(width: RayChat.sendButton, height: RayChat.sendButton)
                .background(canSend ? EdenColor.primary80 : EdenColor.black(5), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .disabled(!canSend)
        .help("Send")
        .keyboardShortcut(.return, modifiers: .command)
    }
}

/// `.ccbtn` — a 28 pt circle around a 16 pt glyph, tinting on hover.
struct RayIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(EdenFont.ui(RayChat.iconGlyph - 3))
                .foregroundStyle(isHovering ? EdenColor.n700 : EdenColor.n500)
                .frame(width: RayChat.iconButton, height: RayChat.iconButton)
                .background(isHovering ? EdenColor.black(5) : .clear, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(help)
        .onHover { isHovering = $0 }
    }
}
