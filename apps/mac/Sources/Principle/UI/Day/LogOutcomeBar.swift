import DesignSystem
import PrincipleCore
import SwiftUI

/// The line at the bottom of the day: something that happened but was never on
/// the list (spec #13).
///
/// It lands as a finished, untimed row on this day — which is what makes it a
/// dot when the dots arrive (#8), without a second kind of record to keep in
/// step with the first.
struct LogOutcomeBar: View {
    @Bindable var journal: JournalModel
    /// True once column 3 has become a drawer: the day then runs to the window's
    /// right edge, and Ask Ray's bubble comes down on top of the Log button. The
    /// prototype has the same collision at 960 pt — a button you cannot click is
    /// worth a deviation, so the bar leaves the bubble its corner.
    var clearsAskRay = false

    @State private var title = ""
    @State private var categoryID: UUID?

    var body: some View {
        HStack(spacing: EdenMetric.sidebarInset) {
            TextField("Log an outcome that was never on the list", text: $title)
                .textFieldStyle(.plain)
                .font(EdenFont.ui(13))
                .onSubmit(log)

            if !journal.categories.isEmpty {
                Picker("Category", selection: $categoryID) {
                    ForEach(journal.categories) { category in
                        Text(category.name).tag(UUID?.some(category.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(EdenFont.ui(12))
                .frame(maxWidth: 130)
            }

            Button("Log", action: log)
                .buttonStyle(EdenPillButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.leading, 20)
        .padding(.trailing, clearsAskRay ? DayMetric.bubbleSize + DayMetric.chatMargin : 20)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { EdenColor.black(10).frame(height: 1) }
        .onAppear { categoryID = categoryID ?? journal.categories.first?.id }
        .onChange(of: journal.categories.map(\.id)) { _, ids in
            // A category deleted underneath the picker must not leave it holding
            // an id nothing resolves.
            if categoryID == nil || !ids.contains(where: { $0 == categoryID }) { categoryID = ids.first }
        }
    }

    private func log() {
        guard journal.logOutcome(title: title, categoryID: categoryID) != nil else { return }
        title = ""
    }
}
