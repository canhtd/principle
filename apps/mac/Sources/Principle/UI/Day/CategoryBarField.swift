import DesignSystem
import PrincipleCore
import SwiftUI

extension View {
    /// Writes a Category's Bar in a popover beside the row it belongs to — one
    /// sentence about what a good day there looks like (ADR 0001).
    ///
    /// Beside the category rather than in the Review pane, because the Bar
    /// belongs to the Category and outlives any one day: the pane only reads it.
    func categoryBarEditor(
        _ category: JournalCategory,
        editingID: Binding<UUID?>,
        commit: @escaping (String) -> Void
    ) -> some View {
        modifier(CategoryBarEditor(category: category, editingID: editingID, commit: commit))
    }
}

private struct CategoryBarEditor: ViewModifier {
    let category: JournalCategory
    @Binding var editingID: UUID?
    let commit: (String) -> Void

    @State private var text = ""

    func body(content: Content) -> some View {
        content.popover(isPresented: isOpen, arrowEdge: .trailing) {
            // Return writes it and closes. Writing here rather than leaving it
            // to the dismissal below is the difference between Return saving and
            // Return throwing the sentence away; the second write the dismissal
            // then makes is a no-op, the model having nothing new to file.
            CategoryBarField(category: category, text: $text) {
                commit(text)
                editingID = nil
            }
                // The field opens on what is on file, so re-opening it shows the
                // sentence rather than an empty box asking for it again.
                .onAppear { text = category.bar ?? "" }
        }
    }

    /// A native popover, so Escape and a click away close it — and closing it is
    /// what saves, the way the rename field commits when it loses the caret.
    /// There is no Save here either.
    private var isOpen: Binding<Bool> {
        Binding(
            get: { editingID == category.id },
            set: { open in
                if open {
                    editingID = category.id
                } else if editingID == category.id {
                    commit(text)
                    editingID = nil
                }
            }
        )
    }
}

/// The Bar itself: a label saying what the sentence is for, and the sentence.
///
/// It is allowed to stay empty — a Category with no bar is judged by feel, and
/// emptying the field is how the bar is taken back.
private struct CategoryBarField: View {
    let category: JournalCategory
    @Binding var text: String
    let done: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The bar for \(category.name)")
                .font(EdenFont.ui(11))
                .tracking(11 * 0.05)
                .foregroundStyle(EdenColor.hex(0x77746F))

            TextField("What a good day here looks like.", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(EdenFont.ui(13))
                .lineSpacing(13 * 0.45)
                .foregroundStyle(EdenColor.textPrimary)
                // Three lines of room from the start, whether or not there is
                // anything in them: a popover takes its size from the first
                // layout, so a field that grows as the sentence is typed grows
                // inside a window that no longer fits it.
                .lineLimit(3, reservesSpace: true)
                .focused($isFocused)
                .onSubmit(done)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(EdenColor.hex(0xF7F7F7), in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
                .edenBorder(isFocused ? EdenColor.olive : EdenColor.black(10), radius: EdenRadius.sm)

            Text("Leave it empty for none — a dot can be felt rather than measured.")
                .font(EdenFont.ui(11))
                .foregroundStyle(EdenColor.n400)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 300)
        .onAppear { isFocused = true }
    }
}
