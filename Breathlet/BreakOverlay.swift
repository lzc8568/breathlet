import AppKit
import SwiftUI

@MainActor
final class BreakOverlayManager {
    private var windows: [NSWindow] = []

    func show(
        duration: Int,
        preferences: Preferences,
        healthTip: HealthTip,
        message: String,
        onSkip: @escaping () -> Void
    ) {
        hide()

        for screen in NSScreen.screens {
            let window = BreakOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false

            let view = BreakOverlayView(
                duration: duration,
                opacity: Double(preferences.maskOpacityPercent) / 100.0,
                healthTip: healthTip,
                message: message,
                enableGradualWakeUp: preferences.enableGradualWakeUp,
                gradualWakeUpSeconds: preferences.gradualWakeUpSeconds,
                onSkip: onSkip
            )
            window.contentView = NSHostingView(rootView: view)
            window.alphaValue = preferences.fadeInMaskWindow ? 0 : 1
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

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

private final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct BreakOverlayView: View {
    let duration: Int
    let opacity: Double
    let healthTip: HealthTip
    let message: String
    let enableGradualWakeUp: Bool
    let gradualWakeUpSeconds: Int
    let onSkip: () -> Void

    @State private var remaining: Int
    @State private var timer: Timer?
    @State private var fadeTask: Task<Void, Never>?
    @State private var fadeAlpha: Double = 1.0
    @State private var isIconAnimating = false
    @State private var actionIndex = 0
    @State private var actionTick = 0

    init(
        duration: Int,
        opacity: Double,
        healthTip: HealthTip,
        message: String,
        enableGradualWakeUp: Bool,
        gradualWakeUpSeconds: Int,
        onSkip: @escaping () -> Void
    ) {
        self.duration = max(duration, 1)
        self.opacity = opacity
        self.healthTip = healthTip
        self.message = message
        self.enableGradualWakeUp = enableGradualWakeUp
        self.gradualWakeUpSeconds = max(gradualWakeUpSeconds, 1)
        self.onSkip = onSkip
        _remaining = State(initialValue: max(duration, 1))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(opacity * fadeAlpha)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Image(systemName: currentActionSymbol)
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.white.opacity(isIconAnimating ? 0.72 : 0.94))
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(isIconAnimating ? 1.08 : 0.96)
                        .offset(x: actionOffset)
                        .id(currentActionSymbol)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82).combined(with: .opacity),
                            removal: .scale(scale: 1.12).combined(with: .opacity)
                        ))
                }
                .frame(width: 100, height: 72)
                .animation(
                    .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: isIconAnimating
                )
                .animation(.easeInOut(duration: 0.38), value: currentActionSymbol)

                if !trimmedMessage.isEmpty {
                    Text(trimmedMessage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(timeString)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.top, 2)

                Button("Skip Break") {
                    onSkip()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.white.opacity(0.2))
            }
            .padding(32)
        }
        .onAppear {
            startTimer()
            startWakeUpFade()
            isIconAnimating = true
        }
        .onDisappear {
            timer?.invalidate()
            fadeTask?.cancel()
        }
    }

    private var timeString: String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var actionSymbols: [String] {
        var symbols = [
            healthTip.symbolName,
            "figure.walk",
            "figure.stand",
            "figure.mind.and.body",
            "figure.strengthtraining.traditional",
            "hand.raised",
            "wind"
        ]
        symbols.removeAll { $0.isEmpty }
        return Array(NSOrderedSet(array: symbols)) as? [String] ?? symbols
    }

    private var currentActionSymbol: String {
        let symbols = actionSymbols
        return symbols[actionIndex % symbols.count]
    }

    private var actionOffset: CGFloat {
        switch actionIndex % 3 {
        case 0: return -4
        case 1: return 4
        default: return 0
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                remaining = max(remaining - 1, 0)
                actionTick += 1
                if actionTick.isMultiple(of: 2) {
                    withAnimation(.easeInOut(duration: 0.38)) {
                        actionIndex = (actionIndex + 1) % actionSymbols.count
                    }
                }
                if remaining == 0 {
                    onSkip()
                }
            }
        }
    }

    private func startWakeUpFade() {
        guard enableGradualWakeUp else { return }

        let fadeSeconds = min(gradualWakeUpSeconds, duration)
        let delaySeconds = max(duration - fadeSeconds, 0)

        fadeTask?.cancel()
        fadeTask = Task {
            if delaySeconds > 0 {
                try? await Task.sleep(for: .seconds(delaySeconds))
            }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.linear(duration: Double(fadeSeconds))) {
                    fadeAlpha = 0
                }
            }
        }
    }
}
