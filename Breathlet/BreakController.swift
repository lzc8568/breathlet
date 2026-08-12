import AppKit
import Combine

/// 纯函数：把秒数格式化为 mm:ss，供菜单栏与测试复用。
enum TimeFormat {
    static func string(seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        let minutes = safeSeconds / 60
        let seconds = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// 纯函数：根据当前已完成的眼部休息次数，计算下一次休息类型。
/// 站立休息只统计「自动触发的眼部休息」，手动休息不推进进度。
enum BreakScheduler {
    static func nextKind(
        completedEyeBreaks: Int,
        enableStandupBreak: Bool,
        standupEveryEyeBreaks: Int
    ) -> (kind: BreakKind, completedEyeBreaks: Int) {
        guard enableStandupBreak else { return (.eye, completedEyeBreaks) }
        let updated = completedEyeBreaks + 1
        return updated.isMultiple(of: max(standupEveryEyeBreaks, 1))
            ? (.standup, updated)
            : (.eye, updated)
    }
}

@MainActor
final class BreakController: ObservableObject {
    @Published private(set) var remainingWorkSeconds: Int
    @Published private(set) var isBreakActive = false
    @Published private(set) var isPaused = false

    /// 休息正式开始前的预告倒计时秒数。
    private static let breakCountdownSeconds = 5

    private let preferences: Preferences
    private let overlay = BreakOverlayManager()
    private var timer: Timer?
    private var breakEndsAt: Date?
    private var workEndsAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private var currentIntervalMinutes: Int
    private var completedEyeBreaks = 0
    private var pendingBreakKind: BreakKind?
    private var countdownTask: Task<Void, Never>?
    private var activityGuard: ActivityGuard?

    /// 持有 App Nap 防护；deinit 时自动结束活动断言。
    private final class ActivityGuard {
        let token: NSObjectProtocol
        init(options: ProcessInfo.ActivityOptions, reason: String) {
            token = ProcessInfo.processInfo.beginActivity(options: options, reason: reason)
        }
        deinit {
            ProcessInfo.processInfo.endActivity(token)
        }
    }

    init(preferences: Preferences) {
        self.preferences = preferences
        currentIntervalMinutes = max(preferences.eyeBreakEveryMinutes, 1)
        remainingWorkSeconds = currentIntervalMinutes * 60
        workEndsAt = Date().addingTimeInterval(TimeInterval(remainingWorkSeconds))
        start()

        // 允许系统空闲睡眠，但防止 App Nap 节流 1 秒计时器。
        activityGuard = ActivityGuard(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Breathlet 工作计时"
        )

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let nextInterval = max(preferences.eyeBreakEveryMinutes, 1)
                    guard nextInterval != self.currentIntervalMinutes else { return }
                    self.currentIntervalMinutes = nextInterval
                    self.resetWorkTimer()
                }
            }
            .store(in: &cancellables)
    }

    var menuBarTitle: String {
        guard preferences.showTimeInMenuBar else {
            return isBreakActive
                ? NSLocalizedString("Break", comment: "")
                : (isPaused ? NSLocalizedString("Paused", comment: "") : "Breathlet")
        }
        return isBreakActive
            ? NSLocalizedString("Break", comment: "")
            : (isPaused ? NSLocalizedString("Paused", comment: "") : TimeFormat.string(seconds: remainingWorkSeconds))
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        // 加入 .common mode：菜单打开（event tracking）时计数仍继续刷新。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func triggerBreakNow() {
        cancelScheduledBreak(resetTimer: false)
        beginBreak(kind: .eye)
    }

    func skipBreak() {
        if isBreakActive {
            endBreak(playSound: false)
        } else {
            cancelScheduledBreak()
        }
    }

    func pause() {
        guard !isBreakActive, !isPaused else { return }
        isPaused = true
        workEndsAt = nil
    }

    func resume() {
        guard !isBreakActive, isPaused else { return }
        isPaused = false
        workEndsAt = Date().addingTimeInterval(TimeInterval(max(remainingWorkSeconds, 0)))
    }

    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    func resetWorkTimer() {
        cancelScheduledBreak(resetTimer: false)
        remainingWorkSeconds = max(preferences.eyeBreakEveryMinutes, 1) * 60
        workEndsAt = Date().addingTimeInterval(TimeInterval(remainingWorkSeconds))
        if isBreakActive {
            endBreak(playSound: false)
        }
    }

    private func tick() {
        if isBreakActive {
            if let breakEndsAt, Date() >= breakEndsAt {
                endBreak(playSound: preferences.playSoundWhenBreakEnds)
            }
            return
        }

        if isPaused {
            return
        }

        if pendingBreakKind != nil {
            return
        }

        if preferences.pauseWhenMouseInactive, userHasBeenInactiveLongEnough {
            return
        }

        guard let workEndsAt else {
            resetWorkTimer()
            return
        }

        remainingWorkSeconds = max(Int(workEndsAt.timeIntervalSinceNow.rounded(.up)), 0)
        if Date() >= workEndsAt {
            remainingWorkSeconds = 0
            beginScheduledBreak(kind: scheduledBreakKind())
        }
    }

    /// 检测多种输入事件（鼠标移动/拖动/点击、滚轮、键盘），任一事件超过阈值即视为不活动。
    private var userHasBeenInactiveLongEnough: Bool {
        let eventTypes: [CGEventType] = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown
        ]
        let idle = eventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
        return idle >= TimeInterval(max(preferences.mouseInactiveMinutes, 1)) * 60
    }

    /// 自动触发的休息先显示预告倒计时，给用户收尾和取消的机会。
    private func beginScheduledBreak(kind: BreakKind) {
        guard !isBreakActive, pendingBreakKind == nil else { return }

        pendingBreakKind = kind
        overlay.showCountdown(seconds: Self.breakCountdownSeconds) { [weak self] in
            self?.cancelScheduledBreak()
        }

        countdownTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.breakCountdownSeconds))
            guard !Task.isCancelled else { return }
            guard let self, self.pendingBreakKind == kind, !self.isBreakActive else { return }
            self.pendingBreakKind = nil
            self.countdownTask = nil
            self.beginBreak(kind: kind)
        }
    }

    /// 取消预告倒计时；默认重置工作计时（等同一次跳过）。
    private func cancelScheduledBreak(resetTimer: Bool = true) {
        guard pendingBreakKind != nil else { return }
        pendingBreakKind = nil
        countdownTask?.cancel()
        countdownTask = nil
        overlay.hideCountdown()
        if resetTimer {
            remainingWorkSeconds = max(preferences.eyeBreakEveryMinutes, 1) * 60
            workEndsAt = Date().addingTimeInterval(TimeInterval(remainingWorkSeconds))
        }
    }

    private func beginBreak(kind: BreakKind) {
        guard !isBreakActive else { return }
        SettingsWindowController.shared.hideForBreak()
        overlay.hide()
        isBreakActive = true
        let duration = kind == .standup
            ? max(preferences.standupBreakDurationMinutes, 1) * 60
            : max(preferences.eyeBreakDurationSeconds, 1)
        let endDate = Date().addingTimeInterval(TimeInterval(duration))
        breakEndsAt = endDate

        let healthTip = HealthTipProvider.shared.getNextTip()

        overlay.show(
            duration: duration,
            breakEndsAt: endDate,
            preferences: preferences,
            healthTip: healthTip,
            message: preferences.breakMessage
        ) { [weak self] in
            self?.endBreak(playSound: false)
        }
    }

    private func scheduledBreakKind() -> BreakKind {
        let result = BreakScheduler.nextKind(
            completedEyeBreaks: completedEyeBreaks,
            enableStandupBreak: preferences.enableStandupBreak,
            standupEveryEyeBreaks: preferences.standupEveryEyeBreaks
        )
        completedEyeBreaks = result.completedEyeBreaks
        return result.kind
    }

    private func endBreak(playSound: Bool) {
        overlay.hide()
        isBreakActive = false
        breakEndsAt = nil
        pendingBreakKind = nil
        countdownTask?.cancel()
        countdownTask = nil
        resetWorkTimerAfterBreak()

        if playSound {
            NSSound(named: "Glass")?.play()
        }
    }

    private func resetWorkTimerAfterBreak() {
        remainingWorkSeconds = max(preferences.eyeBreakEveryMinutes, 1) * 60
        workEndsAt = Date().addingTimeInterval(TimeInterval(remainingWorkSeconds))
    }
}
