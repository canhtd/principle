import PrincipleCore
import SwiftUI

struct ContentView: View {
    @State private var section: AppSection = .chat
    /// Built from Settings (KTD4/KTD5): the repo the stores read and the exact
    /// binary to spawn. Read once at launch, which is why Settings says a change
    /// takes effect after reopening the app.
    @State private var model: SessionViewModel
    /// Same repo, and the corpus the chat already loaded — the file is parsed
    /// once per launch, not once per section.
    @State private var favorites: FavoritesModel
    @State private var isCreatingSession = false
    /// Pinned open: the session list is how a consultation is found again (R1),
    /// and AppKit otherwise restores whatever collapsed state it saw last.
    @State private var columns = NavigationSplitViewVisibility.all

    init() {
        let settings = AppSettings()
        let model = SessionViewModel.live(
            repoURL: settings.repoURL,
            binaryOverride: settings.engineOverridePath
        )
        _model = State(initialValue: model)
        _favorites = State(initialValue: FavoritesModel(repoURL: settings.repoURL, corpus: model.corpus))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Section", selection: $section) {
                    ForEach(AppSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("New Session", systemImage: "square.and.pencil") { isCreatingSession = true }
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
                    if favorites.isEmpty {
                        Label(FavoritesModel.emptyTitle, systemImage: AppSection.favorites.systemImage)
                            .foregroundStyle(.secondary)
                    } else {
                        Label(savedCount, systemImage: "heart.fill")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Principle")
        }
    }

    private var savedCount: String {
        let count = favorites.ids.count
        return "\(count) principle\(count == 1 ? "" : "s") saved"
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .chat:
            if model.isEngineBlocked {
                EngineStatusView(model: model)
            } else if model.currentSession != nil {
                ChatView(model: model, favorites: favorites)
            } else {
                ContentUnavailableView {
                    Label(AppSection.chat.title, systemImage: AppSection.chat.systemImage)
                } description: {
                    Text("Tell Ray a situation to get started.")
                } actions: {
                    Button("New Session") { isCreatingSession = true }
                }
            }
        case .favorites:
            FavoritesView(favorites: favorites) { section = .chat }
                .navigationTitle(AppSection.favorites.title)
        }
    }
}

#Preview {
    ContentView()
}
