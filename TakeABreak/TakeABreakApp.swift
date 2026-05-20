import SwiftUI

@main
struct TakeABreakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(Preferences.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var controller: BreakController?
    private var menuUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let preferences = Preferences.shared
        let controller = BreakController(preferences: preferences)
        self.controller = controller

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        statusItem.button?.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Take a Break")
        statusItem.button?.imagePosition = .imageLeading

        rebuildMenu()
        updateMenuBarTitle()

        menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateMenuBarTitle()
                self?.rebuildMenu()
            }
        }
    }

    private func updateMenuBarTitle() {
        statusItem?.button?.title = " \(controller?.menuBarTitle ?? "Take a Break")"
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let stateItem = NSMenuItem(title: controller?.isBreakActive == true ? "Break is running" : "Next break in \(controller?.menuBarTitle ?? "--:--")", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: "b"))
        menu.addItem(NSMenuItem(title: "Reset Timer", action: #selector(resetTimer), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Take a Break", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func takeBreakNow() {
        controller?.triggerBreakNow()
    }

    @objc private func resetTimer() {
        controller?.resetWorkTimer()
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
