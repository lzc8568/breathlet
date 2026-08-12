import Foundation
import SwiftUI

enum BreakKind: String, CaseIterable, Identifiable {
    case eye
    case standup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eye: NSLocalizedString("Eye", comment: "")
        case .standup: NSLocalizedString("Standup", comment: "")
        }
    }
}

enum BreakSettingsTab: String, CaseIterable, Identifiable {
    case schedule
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: NSLocalizedString("Schedule", comment: "")
        case .appearance: NSLocalizedString("Appearance", comment: "")
        }
    }
}

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    @AppStorage("launchAtStartup") var launchAtStartup = false
    @AppStorage("showTimeInMenuBar") var showTimeInMenuBar = true
    @AppStorage("playSoundWhenBreakEnds") var playSoundWhenBreakEnds = true
    @AppStorage("fadeInMaskWindow") var fadeInMaskWindow = true
    @AppStorage("pauseWhenMouseInactive") var pauseWhenMouseInactive = false
    @AppStorage("enableStandupBreak") var enableStandupBreak = false

    @AppStorage("eyeBreakEveryMinutes") var eyeBreakEveryMinutes = 20
    @AppStorage("eyeBreakDurationSeconds") var eyeBreakDurationSeconds = 20
    @AppStorage("standupBreakDurationMinutes") var standupBreakDurationMinutes = 5
    @AppStorage("standupEveryEyeBreaks") var standupEveryEyeBreaks = 2

    @AppStorage("maskOpacityPercent") var maskOpacityPercent = 82
    @AppStorage("breakMessage") var breakMessage = NSLocalizedString("Time to take a break", comment: "")

    @AppStorage("enableGradualWakeUp") var enableGradualWakeUp = true
    @AppStorage("gradualWakeUpSeconds") var gradualWakeUpSeconds = 5

    private init() {}
}
