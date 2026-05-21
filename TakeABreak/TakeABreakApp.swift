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
        SettingsWindowController.shared.show()
    }
}

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if let window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = PreferencesView()
            .environmentObject(Preferences.shared)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Take a Break Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
