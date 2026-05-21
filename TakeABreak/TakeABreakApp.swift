import SwiftUI

@main
struct TakeABreakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller: BreakController

    init() {
        _controller = StateObject(wrappedValue: BreakController(preferences: Preferences.shared))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(controller)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer")
                Text(controller.menuBarTitle)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(Preferences.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct MenuBarContentView: View {
    @EnvironmentObject private var controller: BreakController

    var body: some View {
        Text(controller.isBreakActive ? "Break is running" : "Next break in \(controller.menuBarTitle)")

        Divider()

        Button("Take Break Now") {
            controller.triggerBreakNow()
        }
        .keyboardShortcut("b")

        Button("Reset Timer") {
            controller.resetWorkTimer()
        }
        .keyboardShortcut("r")

        Divider()

        Button("Preferences...") {
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Take a Break") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
