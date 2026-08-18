import PrincipleCore
import SwiftUI

/// The app opens on the day (spec #5 rev 2). Chat is no longer a section beside
/// it: Ask Ray is a bubble on the day itself, because a question about today is
/// asked while looking at today.
struct ContentView: View {
    /// Built from Settings (KTD4/KTD5): the repo the stores read and the exact
    /// binary to spawn. Read once at launch, which is why Settings says a change
    /// takes effect after reopening the app.
    @State private var session: SessionViewModel
    /// Same repo, and the corpus the chat already loaded — the file is parsed
    /// once per launch, not once per panel.
    @State private var favorites: FavoritesModel
    private let repoURL: URL

    init() {
        let settings = AppSettings()
        let session = SessionViewModel.live(
            repoURL: settings.repoURL,
            binaryOverride: settings.engineOverridePath
        )
        repoURL = settings.repoURL
        _session = State(initialValue: session)
        _favorites = State(initialValue: FavoritesModel(repoURL: settings.repoURL, corpus: session.corpus))
    }

    var body: some View {
        DayShell(repoURL: repoURL, session: session, favorites: favorites)
            // KTD4: probe once at launch so a logged-out engine is visible
            // before the first question rather than after it.
            .task { await session.refreshAvailability() }
    }
}

#Preview {
    ContentView()
}
