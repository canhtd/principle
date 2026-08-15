import PrincipleCore
import SwiftUI

struct ContentView: View {
    @State private var section: AppSection = .chat
    /// Built from Settings (KTD4/KTD5): the repo the stores read and the exact
    /// binary to spawn. Read once at launch, which is why Settings says a change
    /// takes effect after reopening the app.
    @State private var model = SessionViewModel.live(
        repoURL: AppSettings().repoURL,
        binaryOverride: AppSettings().engineOverridePath
    )
    @State private var isCreatingSession = false
    /// Pinned open: the session list is how a consultation is found again (R1),
    /// and AppKit otherwise restores whatever collapsed state it saw last.
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
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
            ToolbarItem(placement: .primaryAction) {
                Button("Phiên mới", systemImage: "square.and.pencil") { isCreatingSession = true }
                    .disabled(section != .chat)
            }
        }
        .sheet(isPresented: $isCreatingSession) {
            NewSessionSheet { draft in model.createSession(from: draft) }
        }
        // KTD4: probe once at launch so a logged-out engine is visible before
        // the first question rather than after it.
        .task { await model.refreshAvailability() }
    }

    @ViewBuilder
    private var sidebar: some View {
        switch section {
        case .chat:
            SidebarView(model: model, isCreatingSession: $isCreatingSession)
        case .favorites:
            List {
                Section(AppSection.favorites.title) {
                    Label("Chưa lưu nguyên tắc nào", systemImage: AppSection.favorites.systemImage)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Principle")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .chat:
            if model.isEngineBlocked {
                EngineStatusView(model: model)
            } else if model.currentSession != nil {
                ChatView(model: model)
            } else {
                ContentUnavailableView {
                    Label(AppSection.chat.title, systemImage: AppSection.chat.systemImage)
                } description: {
                    Text("Hỏi Ray một tình huống để bắt đầu.")
                } actions: {
                    Button("Phiên mới") { isCreatingSession = true }
                }
            }
        case .favorites:
            ContentUnavailableView {
                Label(AppSection.favorites.title, systemImage: AppSection.favorites.systemImage)
            } description: {
                Text("Những nguyên tắc anh đánh dấu sẽ hiện ở đây.")
            }
        }
    }
}

#Preview {
    ContentView()
}
