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
    /// The row under the pointer, which is the only one wearing its "…".
    @State private var hoveredCategoryID: UUID?
    @FocusState private var renameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarSectionHeader(
                title: "Categories",
                isExpanded: ui.categoriesExpanded,
                toggle: { withAnimation(.easeOut(duration: 0.15)) { ui.categoriesExpanded.toggle() } },
                add: startAdding,
                addHelp: "New category"
            )
            if ui.categoriesExpanded {
                VStack(spacing: 2) {
                    ForEach(journal.categories) { category in
                        row(category)
                    }
                    // The empty state is the same field the "+" opens, standing
                    // open: a journal with no categories has nothing else to
                    // offer, and a colour is what makes a day readable.
                    if ui.isAddingCategory || journal.categories.isEmpty { newField }
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
                more(category)
            }
        }
        .help(isShown ? "Hide \(category.name)" : "Show \(category.name)")
        .onHover { hoveredCategoryID = $0 ? category.id : nil }
        .onTapGesture { journal.toggleVisibility(of: category.id) }
        .contextMenu { menu(category) }
    }

    /// The "…" at the row's right edge, on hover — the same menu right-click
    /// opens, for the half of the world that never right-clicks. A menu is not
    /// discoverable if the only way to find it is to already know it is there.
    private func more(_ category: JournalCategory) -> some View {
        let isShowing = hoveredCategoryID == category.id
        return Menu {
            menu(category)
        } label: {
            Image(systemName: "ellipsis")
                .font(EdenFont.ui(11, .semibold))
                .foregroundStyle(EdenColor.n500)
                .frame(width: 18, height: 18)
                .contentShape(.rect)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 18, height: 18)
        .focusEffectDisabled()
        .opacity(isShowing ? 1 : 0)
        // Invisible is not clickable: the tick-and-name row must keep the whole
        // width to click on while nothing is hovering it.
        .allowsHitTesting(isShowing)
        .help("Category options")
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
                    // Drawn, not an SF Symbol: see DayPalette.swatch.
                    Image(nsImage: DayPalette.swatch(
                        DayPalette.colors[key] ?? EdenColor.n500,
                        isCurrent: category.colorKey == key
                    ))
                    Text(key.capitalized)
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

    /// The "+" opens the section it belongs to before it opens the field —
    /// typing into a list you cannot see is nobody's idea of feedback.
    private func startAdding() {
        withAnimation(.easeOut(duration: 0.15)) {
            ui.categoriesExpanded = true
            ui.isAddingCategory = true
        }
    }

    private var newField: some View {
        NewCategoryField(autoFocus: ui.isAddingCategory) {
            journal.addCategory(name: $0)
        } done: {
            ui.isAddingCategory = false
        }
    }
}

/// Type a name, press Enter. The only way to make a category until the
/// Categories screen exists (#10) — and what the header's "+" opens.
struct NewCategoryField: View {
    /// True when the field was asked for, false when it is the empty state
    /// standing open: taking the caret on launch would be rude.
    var autoFocus = false
    let add: (String) -> Void
    var done: (() -> Void)?

    @State private var name = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        SidebarRow {
            Image(systemName: "plus")
                .font(EdenFont.ui(11, .medium))
                .foregroundStyle(EdenColor.n400)
                .frame(width: 15)
            TextField("New category", text: $name)
                .textFieldStyle(.plain)
                .font(EdenFont.ui(14))
                .focused($isFocused)
                .onSubmit {
                    add(name)
                    name = ""
                    done?()
                }
        }
        .onAppear { if autoFocus { isFocused = true } }
        // Clicking away is how a field like this is abandoned; an empty one
        // closes rather than sitting there waiting.
        .onChange(of: isFocused) { _, focused in
            if !focused, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { done?() }
        }
    }
}
