import PrincipleCore
import SwiftUI

/// The profile Ray reads before every consult: the `## Hồ sơ người hỏi` section
/// of `memory/MEMORY.md`, edited in place.
///
/// Free-form markdown on purpose — the engine reads prose, not fields, so the
/// screen is one text area plus the three things a shared file needs: whether
/// there is anything unsaved, a way back to the saved copy, and the write error
/// when there is one.
struct ProfileView: View {
    let store: ProfileStore

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    /// The copy on disk as of the last load or save — what "unsaved" is
    /// measured against, and what Revert goes back to.
    @State private var saved = ""
    @State private var errorMessage: String?

    static let caption = """
        Ray reads this before every consult. Write it the way you'd brief a mentor: \
        who you are, what you're working on, recurring patterns.
        """

    private var isDirty: Bool { draft != saved }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            Text("Profile")
                .font(Typography.title)
                .lineSpacing(Typography.titleLineSpacing)
            Text(Self.caption)
                .font(Typography.caption)
                .lineSpacing(Typography.captionLineSpacing)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            editor
            status
            buttons
        }
        .padding(20)
        .frame(width: 520, height: 480)
        // A terminal session may have rewritten MEMORY.md since the app opened.
        .onAppear(perform: reload)
    }

    // MARK: - Pieces

    private var editor: some View {
        TextEditor(text: $draft)
            .font(Typography.body)
            .lineSpacing(Typography.bodyLineSpacing)
            .scrollContentBackground(.hidden)
            .padding(Spacing.headingTop)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.3))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var status: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.caption)
                .lineSpacing(Typography.captionLineSpacing)
                .foregroundStyle(.orange)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttons: some View {
        HStack(spacing: Spacing.block) {
            Text(isDirty ? "Unsaved changes" : "Saved")
                .font(Typography.caption)
                .foregroundStyle(isDirty ? .orange : .secondary)
            Spacer()
            Button("Revert") { draft = saved }
                .disabled(!isDirty)
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Save", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(!isDirty)
        }
    }

    // MARK: - Actions

    private func reload() {
        saved = store.load()
        draft = saved
        errorMessage = nil
    }

    private func save() {
        do {
            try store.save(draft)
            // What landed on disk, not what was typed: the store trims, so
            // reading back is what keeps "Saved" honest.
            saved = store.load()
            draft = saved
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ProfileView(store: ProfileStore(repoURL: RepoLocation.current()))
}
