import PrincipleCore
import SwiftUI

/// Consultations grouped by the day they started (R1). Every session has a
/// topic, so a row never reads as "chat 3".
struct SidebarView: View {
    @Bindable var model: SessionViewModel
    @Binding var isCreatingSession: Bool

    var body: some View {
        List(selection: $model.selection) {
            ForEach(model.groups) { group in
                Section(DayLabel.text(for: group.day)) {
                    ForEach(group.sessions) { session in
                        SessionRow(session: session).tag(session.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if model.groups.isEmpty {
                ContentUnavailableView {
                    Label("No conversations yet", systemImage: AppSection.chat.systemImage)
                } description: {
                    Text("Create a session and tell Ray the situation.")
                } actions: {
                    Button("New Session") { isCreatingSession = true }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !model.skippedFiles.isEmpty {
                Label(skippedLabel, systemImage: "exclamationmark.triangle")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .navigationTitle("Principle")
    }

    private var skippedLabel: String {
        let count = model.skippedFiles.count
        return "\(count) session file\(count == 1 ? "" : "s") could not be read"
    }
}

private struct SessionRow: View {
    let session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.topic)
                .font(Typography.body)
                .lineSpacing(Typography.captionLineSpacing)
                .lineLimit(2)
            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let time = session.createdAt.formatted(date: .omitted, time: .shortened)
        let count = session.messages.count
        guard count > 0 else { return "\(time) · no questions yet" }
        return "\(time) · \(count) message\(count == 1 ? "" : "s")"
    }
}

/// Section headers: recent days get a name, older ones a date.
enum DayLabel {
    static func text(for day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(english))
    }

    /// The app speaks English regardless of the Mac's region, so the header does
    /// not switch language halfway down the list.
    private static let english = Locale(identifier: "en_US")
}

#Preview {
    SidebarView(model: .live(), isCreatingSession: .constant(false))
}
