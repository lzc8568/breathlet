import AppKit
import Combine

@MainActor
final class BreakController: ObservableObject {
    @Published private(set) var remainingWorkSeconds: Int
    @Published private(set) var isBreakActive = false

    private let preferences: Preferences
    private let overlay = BreakOverlayManager()
    private var timer: Timer?
    private var breakEndsAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private var currentIntervalMinutes: Int

    init(preferences: Preferences) {
        self.preferences = preferences
        currentIntervalMinutes = max(preferences.eyeBreakEveryMinutes, 1)
        remainingWorkSeconds = currentIntervalMinutes * 60
        start()

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
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
            return isBreakActive ? "Break" : "Take a Break"
        }
        return isBreakActive ? "Break" : format(seconds: remainingWorkSeconds)
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    func triggerBreakNow() {
        beginBreak()
    }

    func skipBreak() {
        endBreak(playSound: false)
    }

    func resetWorkTimer() {
        remainingWorkSeconds = max(preferences.eyeBreakEveryMinutes, 1) * 60
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

        if preferences.pauseWhenMouseInactive, userHasBeenInactiveForFiveMinutes {
            return
        }

        remainingWorkSeconds -= 1
        if remainingWorkSeconds <= 0 {
            beginBreak()
        }
    }

    private var userHasBeenInactiveForFiveMinutes: Bool {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        return idle >= 5 * 60
    }

    private func beginBreak() {
        isBreakActive = true
        let duration = max(preferences.eyeBreakDurationSeconds, 1)
        breakEndsAt = Date().addingTimeInterval(TimeInterval(duration))
        overlay.show(duration: duration, preferences: preferences) { [weak self] in
            self?.endBreak(playSound: false)
        }
    }

    private func endBreak(playSound: Bool) {
        overlay.hide()
        isBreakActive = false
        breakEndsAt = nil
        resetWorkTimerAfterBreak()

        if playSound {
            NSSound(named: "Glass")?.play()
        }
    }

    private func resetWorkTimerAfterBreak() {
        remainingWorkSeconds = max(preferences.eyeBreakEveryMinutes, 1) * 60
    }

    private func format(seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        let minutes = safeSeconds / 60
        let seconds = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
