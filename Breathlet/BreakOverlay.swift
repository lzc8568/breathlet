import AppKit
import Combine
import SwiftUI

@MainActor
final class BreakOverlayManager {
    private var windows: [NSWindow] = []
    private var countdownWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var activeContext: BreakContext?

    private struct BreakContext {
        let duration: Int
        let breakEndsAt: Date
        let preferences: Preferences
        let healthTip: HealthTip
        let message: String
        let onSkip: () -> Void
    }

    func show(
        duration: Int,
        breakEndsAt: Date,
        preferences: Preferences,
        healthTip: HealthTip,
        message: String,
        onSkip: @escaping () -> Void
    ) {
        hide()
        activeContext = BreakContext(
            duration: duration,
            breakEndsAt: breakEndsAt,
            preferences: preferences,
            healthTip: healthTip,
            message: message,
            onSkip: onSkip
        )
        buildBreakWindows()

        // 休息期间显示器热插拔时重建遮罩，覆盖新增或变化后的屏幕。
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.rebuildBreakWindows()
                }
            }
            .store(in: &cancellables)
    }

    func hide() {
        hideCountdown()
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        activeContext = nil
        cancellables.removeAll()
    }

    /// 休息前的预告倒计时小窗：不抢焦点，用户可继续工作或点取消。
    func showCountdown(seconds: Int, onCancel: @escaping () -> Void) {
        hideCountdown()
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let width: CGFloat = 360
        let height: CGFloat = 150
        let contentRect = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.midY - height / 2,
            width: width,
            height: height
        )

        let window = BreakCountdownWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.contentView = NSHostingView(
            rootView: BreakCountdownView(seconds: seconds, onCancel: onCancel)
        )
        window.orderFrontRegardless()
        countdownWindow = window
    }

    func hideCountdown() {
        countdownWindow?.orderOut(nil)
        countdownWindow = nil
    }

    private func buildBreakWindows() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        guard let context = activeContext else { return }

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
                duration: context.duration,
                breakEndsAt: context.breakEndsAt,
                opacity: Double(context.preferences.maskOpacityPercent) / 100.0,
                healthTip: context.healthTip,
                message: context.message,
                enableGradualWakeUp: context.preferences.enableGradualWakeUp,
                gradualWakeUpSeconds: context.preferences.gradualWakeUpSeconds,
                onSkip: context.onSkip
            )
            window.contentView = NSHostingView(rootView: view)
            window.alphaValue = context.preferences.fadeInMaskWindow ? 0 : 1
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            if context.preferences.fadeInMaskWindow {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.35
                    window.animator().alphaValue = 1
                }
            }

            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func rebuildBreakWindows() {
        guard activeContext != nil else { return }
        buildBreakWindows()
    }
}

private final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 预告倒计时窗口不成为 key window，避免打断用户正在进行的输入。
private final class BreakCountdownWindow: NSWindow {
    override var canBecomeKey: Bool { false }
}

struct BreakCountdownView: View {
    let seconds: Int
    let onCancel: () -> Void

    @State private var remaining: Int
    @State private var timer: Timer?

    init(seconds: Int, onCancel: @escaping () -> Void) {
        self.seconds = max(seconds, 1)
        self.onCancel = onCancel
        _remaining = State(initialValue: max(seconds, 1))
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)

            Text(String(
                format: NSLocalizedString("Break starts in %d", comment: ""),
                remaining
            ))
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .monospacedDigit()

            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.white.opacity(0.25))
        }
        .padding(24)
        .frame(width: 360, height: 150)
        .background(
            Color.black.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                remaining = max(remaining - 1, 0)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

struct BreakOverlayView: View {
    let duration: Int
    let breakEndsAt: Date
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
        breakEndsAt: Date,
        opacity: Double,
        healthTip: HealthTip,
        message: String,
        enableGradualWakeUp: Bool,
        gradualWakeUpSeconds: Int,
        onSkip: @escaping () -> Void
    ) {
        self.duration = max(duration, 1)
        self.breakEndsAt = breakEndsAt
        self.opacity = opacity
        self.healthTip = healthTip
        self.message = message
        self.enableGradualWakeUp = enableGradualWakeUp
        self.gradualWakeUpSeconds = max(gradualWakeUpSeconds, 1)
        self.onSkip = onSkip
        _remaining = State(initialValue: Self.remainingSeconds(until: breakEndsAt))
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
                .controlSize(.large)
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
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                // 剩余时间完全由控制器传入的 breakEndsAt 驱动，
                // 结束动作由控制器统一触发，避免双计时器边界重复。
                remaining = Self.remainingSeconds(until: breakEndsAt)
                actionTick += 1
                if actionTick.isMultiple(of: 2) {
                    withAnimation(.easeInOut(duration: 0.38)) {
                        actionIndex = (actionIndex + 1) % actionSymbols.count
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
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

    private static func remainingSeconds(until date: Date) -> Int {
        max(Int(date.timeIntervalSinceNow.rounded(.up)), 0)
    }
}
