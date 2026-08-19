import DesignSystem
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
    /// Escape and Close both leave; with edits on screen they ask first.
    @State private var isConfirmingDiscard = false

    static let caption = """
        Ray reads this before every consult. Write it the way you'd brief a mentor: \
        who you are, what you're working on, recurring patterns.
        """

    /// Between two blocks of the sheet. `DesignSystem` names faces, not a prose
    /// spacing scale, so the rhythm stays a ratio of the type it separates.
    private static let blockGap = EdenType.row.size * 0.85
    /// Vietnamese needs the leading more than the size: its marks sit above
    /// *and* below the line, so English-ish line-height makes them collide.
    private static let bodyLeading = EdenType.row.size * 0.7
    private static let captionLeading = EdenType.meta.size * 0.4

    private var isDirty: Bool { draft != saved }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.blockGap) {
            Text("Profile")
                .edenText(EdenType.sectionTitle)
            Text(Self.caption)
                .edenText(EdenType.meta)
                .lineSpacing(Self.captionLeading)
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
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your edits to the profile have not been written to MEMORY.md.")
        }
    }

    // MARK: - Pieces

    private var editor: some View {
        TextEditor(text: $draft)
            .font(EdenType.row.font)
            .lineSpacing(Self.bodyLeading)
            .scrollContentBackground(.hidden)
            .padding(EdenType.row.size * 0.5)
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
                .edenText(EdenType.meta)
                .lineSpacing(Self.captionLeading)
                .foregroundStyle(.orange)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttons: some View {
        HStack(spacing: Self.blockGap) {
            Text(isDirty ? "Unsaved changes" : "Saved")
                .edenText(EdenType.meta)
                .foregroundStyle(isDirty ? .orange : .secondary)
            Spacer()
            Button("Revert") { draft = saved }
                .disabled(!isDirty)
            Button("Close", action: close)
                .keyboardShortcut(.cancelAction)
            Button("Save", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(!isDirty)
        }
    }

    // MARK: - Actions

    /// Closing is not a save. The editor holds the only copy of what was
    /// typed, so an unsaved draft has to be given up on purpose.
    private func close() {
        if isDirty { isConfirmingDiscard = true } else { dismiss() }
    }

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
