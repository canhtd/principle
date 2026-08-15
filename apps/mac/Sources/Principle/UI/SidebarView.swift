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
                    Label("Chưa có cuộc trò chuyện nào", systemImage: AppSection.chat.systemImage)
                } description: {
                    Text("Tạo một phiên để kể tình huống của anh.")
                } actions: {
                    Button("Phiên mới") { isCreatingSession = true }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !model.skippedFiles.isEmpty {
                Label("\(model.skippedFiles.count) file phiên không đọc được", systemImage: "exclamationmark.triangle")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .navigationTitle("Principle")
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
        guard !session.messages.isEmpty else { return "\(time) · chưa hỏi" }
        return "\(time) · \(session.messages.count) lượt"
    }
}

/// Section headers: recent days get a name, older ones a date.
enum DayLabel {
    static func text(for day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) { return "Hôm nay" }
        if calendar.isDateInYesterday(day) { return "Hôm qua" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(vietnamese))
    }

    private static let vietnamese = Locale(identifier: "vi_VN")
}

#Preview {
    SidebarView(model: .live(), isCreatingSession: .constant(false))
}
