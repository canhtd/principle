import PrincipleCore
import SwiftUI

struct ContentView: View {
    @State private var section: AppSection = .chat

    var body: some View {
        NavigationSplitView {
            Sidebar(section: section)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            Detail(section: section)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Khu vực", selection: $section) {
                    ForEach(AppSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }
        }
    }
}

private struct Sidebar: View {
    let section: AppSection

    var body: some View {
        List {
            Section(section.title) {
                Label(placeholder, systemImage: section.systemImage)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Principle")
    }

    private var placeholder: String {
        switch section {
        case .chat: "Chưa có cuộc trò chuyện nào"
        case .favorites: "Chưa lưu nguyên tắc nào"
        }
    }
}

private struct Detail: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView {
            Label(section.title, systemImage: section.systemImage)
        } description: {
            Text(description)
        }
    }

    private var description: String {
        switch section {
        case .chat: "Hỏi Ray một tình huống để bắt đầu."
        case .favorites: "Những nguyên tắc anh đánh dấu sẽ hiện ở đây."
        }
    }
}

#Preview {
    ContentView()
}
