import DesignSystem
import PrincipleCore
import SwiftUI

/// Categories as Apple Calendar's calendar list (decision 3): a coloured tick
/// square and a name, ticked by default. Unticking one takes its blocks, its
/// chips and its suggestions off the day — it is a filter, not a setting.
struct CategoryList: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    @State private var draftName = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarSectionHeader(title: "Categories", isExpanded: ui.categoriesExpanded) {
                withAnimation(.easeOut(duration: 0.15)) { ui.categoriesExpanded.toggle() }
            }
            if ui.categoriesExpanded {
                VStack(spacing: 2) {
                    ForEach(journal.categories) { category in
                        row(category)
                    }
                    if journal.categories.isEmpty { emptyRow }
                }
                .padding(.horizontal, EdenMetric.sidebarPadding)
            }
        }
    }

    @ViewBuilder
    private func row(_ category: JournalCategory) -> some View {
        let isShown = journal.isShown(category)
        SidebarRow(isMuted: !isShown) {
            TickBox(isOn: isShown, color: DayPalette.color(category)) {
                journal.toggleVisibility(of: category.id)
            }
            if ui.renamingCategoryID == category.id {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(EdenFont.ui(14))
                    .foregroundStyle(EdenColor.n900)
                    .focused($renameFocused)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(EdenColor.card, in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(EdenColor.primary80, lineWidth: 1.5))
                    .onSubmit { commitRename(category) }
                    // Clicking away commits, the way Finder renames a file;
                    // Escape is handled by the shell and clears the id first.
                    .onChange(of: renameFocused) { _, focused in
                        if !focused, ui.renamingCategoryID == category.id { commitRename(category) }
                    }
            } else {
                Text(category.name).lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .help(isShown ? "Hide \(category.name)" : "Show \(category.name)")
        .onTapGesture { journal.toggleVisibility(of: category.id) }
        .contextMenu { menu(category) }
    }

    /// The four things a category can do, as a native macOS menu (decision 3).
    @ViewBuilder
    private func menu(_ category: JournalCategory) -> some View {
        Button("Rename…") {
            draftName = category.name
            ui.renamingCategoryID = category.id
            renameFocused = true
        }
        Menu("Change color") {
            ForEach(journal.colorKeys, id: \.self) { key in
                Button {
                    journal.recolorCategory(id: category.id, to: key)
                } label: {
                    Label {
                        Text(key.capitalized)
                    } icon: {
                        Image(systemName: category.colorKey == key ? "circle.inset.filled" : "circle.fill")
                            .foregroundStyle(DayPalette.colors[key] ?? EdenColor.n500)
                    }
                }
            }
        }
        Divider()
        Button("Show only \(category.name)") { journal.showOnly(categoryID: category.id) }
        Button("Show all categories") { journal.showAllCategories() }
        Divider()
        // Its tasks survive untagged (see JournalModel.deleteCategory), so this
        // is not the destructive delete Calendar's is.
        Button("Delete Category") { journal.deleteCategory(id: category.id) }
    }

    private func commitRename(_ category: JournalCategory) {
        journal.renameCategory(id: category.id, to: draftName)
        ui.renamingCategoryID = nil
    }

    /// A first run has no categories at all, and a coloured day depends on
    /// having one — so the empty state is the way to make the first.
    private var emptyRow: some View {
        NewCategoryField { journal.addCategory(name: $0) }
    }
}

/// Type a name, press Enter. The only way to make a category until the
/// Categories screen exists (#10).
struct NewCategoryField: View {
    let add: (String) -> Void
    @State private var name = ""

    var body: some View {
        SidebarRow {
            Image(systemName: "plus")
                .font(EdenFont.ui(11, .medium))
                .foregroundStyle(EdenColor.n400)
                .frame(width: 15)
            TextField("New category", text: $name)
                .textFieldStyle(.plain)
                .font(EdenFont.ui(14))
                .onSubmit {
                    add(name)
                    name = ""
                }
        }
    }
}
