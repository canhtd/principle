import AppKit
import SwiftUI

@main
struct PrincipleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Principle") {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
                // The shell paints its own canvas edge to edge, and the day is
                // the title bar's business as much as the window's.
                .ignoresSafeArea(.container, edges: .top)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)

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
        // After the first pass of the run loop: the scene's window does not
        // exist yet at this point, and macOS restores its own frame after that.
        DispatchQueue.main.async { LaunchHooks.applyWindowFrame() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
