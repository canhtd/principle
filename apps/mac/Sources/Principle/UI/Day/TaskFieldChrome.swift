import DesignSystem
import PrincipleCore
import SwiftUI

/// The furniture a task's fields are made of, in one place.
///
/// Two panes ask for the same things now — the one that edits a task that
/// exists, and the one that names a task that does not yet — and a field that
/// looked one way in the first and another in the second would be two designs
/// pretending to be one.

/// A labelled field: the label above, the control below.
struct TaskField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(EdenFont.ui(11))
                .tracking(11 * 0.05)
                .foregroundStyle(EdenColor.hex(0x77746F))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

/// The sunken text field a title and a note are typed into.
struct TaskTextField: View {
    let prompt: String
    @Binding var text: String
    var commit: () -> Void = {}

    var body: some View {
        TextField(prompt, text: $text)
            .textFieldStyle(.plain)
            .font(EdenFont.ui(13))
            .onSubmit(commit)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(EdenColor.hex(0xF7F7F7), in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
            .edenBorder(EdenColor.black(10), radius: EdenRadius.sm)
    }
}

/// Which category a task belongs to, or none — the row that gives a block its
/// colour.
struct TaskCategoryPicker: View {
    let categories: [JournalCategory]
    @Binding var categoryID: UUID?

    var body: some View {
        Picker("Category", selection: $categoryID) {
            Text("None").tag(UUID?.none)
            ForEach(categories) { category in
                Text(category.name).tag(UUID?.some(category.id))
            }
        }
        .labelsHidden()
        .font(EdenFont.ui(13))
    }
}
