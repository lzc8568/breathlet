import AppKit
import SwiftUI

@MainActor
final class BreakOverlayManager {
    private var windows: [NSWindow] = []

    func show(duration: Int, preferences: Preferences, onSkip: @escaping () -> Void) {
        hide()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false

            let view = BreakOverlayView(
                duration: duration,
                message: preferences.breakMessage,
                opacity: Double(preferences.maskOpacityPercent) / 100.0,
                onSkip: onSkip
            )
            window.contentView = NSHostingView(rootView: view)
            window.alphaValue = preferences.fadeInMaskWindow ? 0 : 1
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            if preferences.fadeInMaskWindow {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.35
                    window.animator().alphaValue = 1
                }
            }

            windows.append(window)
        }
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }
}

struct BreakOverlayView: View {
    let duration: Int
    let message: String
    let opacity: Double
    let onSkip: () -> Void

    @State private var remaining: Int
    @State private var timer: Timer?

    init(duration: Int, message: String, opacity: Double, onSkip: @escaping () -> Void) {
        self.duration = max(duration, 1)
        self.message = message
        self.opacity = opacity
        self.onSkip = onSkip
        _remaining = State(initialValue: max(duration, 1))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(opacity)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)

                Text(timeString)
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Button("Skip Break") {
                    onSkip()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.white.opacity(0.2))
            }
            .padding(48)
        }
        .onAppear(perform: startTimer)
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var timeString: String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                remaining = max(remaining - 1, 0)
                if remaining == 0 {
                    onSkip()
                }
            }
        }
    }
}
