import DesignSystem
import PrincipleCore
import SwiftUI

/// The second step of a review: one free-text note for the whole day, under the
/// tracks (`docs/design/proto-review-B.html` v2).
///
/// It saves itself. There is no Save button and no "Saved" flicker (story 13) —
/// the text settles for a moment and is written, and it is written again when
/// the caret leaves, when the day changes and when the pane closes.
struct DayNoteField: View {
    @Bindable var journal: JournalModel

    /// What is being typed. Held here rather than bound straight to the model,
    /// because a binding through a write-and-re-read would put the caret back at
    /// the start of the field on every keystroke.
    @State private var text = ""
    /// The day ``text`` was typed on. Not always the day on screen: the note has
    /// to land on the day it was written about even when the arrow was pressed
    /// a moment after the last letter.
    @State private var noteDay = Date()
    @FocusState private var isFocused: Bool

    /// Long enough that a sentence is one write rather than forty, short enough
    /// that a closed lid loses nothing worth having.
    private static let settle = Duration.milliseconds(600)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Day note")
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.hex(0x77746F))
            editor
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: load)
        // The day moved under the field: what was typed belongs to the day it
        // was typed on, and is written there before the new day is read in.
        .onChange(of: journal.day) { _, _ in
            flush()
            load()
        }
        .onChange(of: isFocused) { _, focused in if !focused { flush() } }
        .onDisappear(perform: flush)
        // The debounce: every keystroke restarts it, and the write lands once
        // the typing stops.
        .task(id: text) {
            guard text != (journal.dayNote ?? "") else { return }
            try? await Task.sleep(for: Self.settle)
            guard !Task.isCancelled else { return }
            journal.setDayNote(text, on: noteDay)
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(EdenFont.ui(13))
            .lineSpacing(13 * 0.6)
            .foregroundStyle(EdenColor.textPrimary)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .frame(minHeight: 92, alignment: .topLeading)
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .background(EdenColor.hex(0xF7F7F7), in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
            .edenBorder(isFocused ? EdenColor.olive : EdenColor.black(10), radius: EdenRadius.sm)
            .overlay(alignment: .topLeading) { placeholder }
    }

    /// `TextEditor` has no prompt of its own, so the line sits behind it and
    /// steps out of the way as soon as there is anything to read.
    @ViewBuilder
    private var placeholder: some View {
        if text.isEmpty {
            Text("What happened today, in your own words.")
                .font(EdenFont.ui(13))
                .foregroundStyle(EdenColor.n400)
                .padding(.horizontal, 10)
                .padding(.vertical, 13)
                .allowsHitTesting(false)
        }
    }

    private func load() {
        text = journal.dayNote ?? ""
        noteDay = journal.day
    }

    /// Writes what is in the field now, on the day it was written for. Text that
    /// has not changed writes nothing, so the field going quiet leaves no line.
    private func flush() {
        journal.setDayNote(text, on: noteDay)
    }
}
