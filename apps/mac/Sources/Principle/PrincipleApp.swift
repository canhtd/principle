import AppKit
import SwiftUI

@main
struct PrincipleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Principle") {
            ContentView()
                .frame(minWidth: 720, minHeight: 460)
        }
        .defaultSize(width: 1040, height: 700)
        .windowToolbarStyle(.unified)

        // ⌘, in the app menu. Everything it edits is written through immediately,
        // so closing the window is the same as saving.
        Settings {
            SettingsView()
        }
    }
}

/// `swift run` starts the executable outside an app bundle, so AppKit treats it
/// as an accessory process: no menu bar and the window opens behind everything.
/// Promoting to `.regular` makes the dev run behave like the installed app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
