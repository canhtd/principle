import Foundation

/// Column 1's category list: what the day is filtered by, and the four things
/// its context menu can do.
extension JournalModel {
    // MARK: - Filtering

    /// Unticking a category takes its blocks, its all-day chips and its
    /// suggestions off the day — Apple Calendar's calendar list, not a setting.
    public func toggleVisibility(of categoryID: UUID) {
        if hiddenCategoryIDs.contains(categoryID) {
            hiddenCategoryIDs.remove(categoryID)
        } else {
            hiddenCategoryIDs.insert(categoryID)
        }
    }

    /// "Show only Learning" — every other category off in one go, which is the
    /// move that takes three clicks otherwise.
    public func showOnly(categoryID: UUID) {
        hiddenCategoryIDs = Set(categories.map(\.id)).subtracting([categoryID])
    }

    public func showAllCategories() {
        hiddenCategoryIDs = []
    }

    // MARK: - Editing the list

    /// A new category takes the next colour in the palette, so the first few in
    /// a fresh journal are visibly different without anyone being asked to pick.
    @discardableResult
    public func addCategory(name: String) -> JournalCategory? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var added: JournalCategory?
        write { store in
            added = try store.addCategory(
                name: trimmed,
                colorKey: JournalPalette.nextColorKey(after: store.categories())
            )
        }
        return added
    }

    public func renameCategory(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != category(id: id)?.name else { return }
        write { try $0.renameCategory(id: id, to: trimmed) }
    }

    public func recolorCategory(id: UUID, to colorKey: String) {
        write { try $0.recolorCategory(id: id, to: colorKey) }
    }

    /// Deletes the category, not its work.
    ///
    /// Apple Calendar takes a calendar's events with it; this does not, and the
    /// difference is deliberate (spec #5, testing decisions). A category here is
    /// a label on work Danny already did or still has to do, and losing "Health"
    /// must not lose the run. Its tasks come back untagged, waiting to be
    /// re-filed.
    public func deleteCategory(id: UUID) {
        write { try $0.deleteCategory(id: id) }
    }

    /// The swatches the "Change color" submenu offers, in palette order.
    public var colorKeys: [String] { JournalPalette.colorKeys }
}
