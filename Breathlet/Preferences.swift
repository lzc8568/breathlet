import Foundation
import SwiftUI

/// UserDefaults / @AppStorage 键名集中管理，避免手写字符串拼错。
enum PreferencesKey {
    static let appLanguage = "appLanguage"
    static let launchAtStartup = "launchAtStartup"
    static let showTimeInMenuBar = "showTimeInMenuBar"
    static let playSoundWhenBreakEnds = "playSoundWhenBreakEnds"
    static let fadeInMaskWindow = "fadeInMaskWindow"
    static let pauseWhenMouseInactive = "pauseWhenMouseInactive"
    static let mouseInactiveMinutes = "mouseInactiveMinutes"
    static let enableStandupBreak = "enableStandupBreak"
    static let eyeBreakEveryMinutes = "eyeBreakEveryMinutes"
    static let eyeBreakDurationSeconds = "eyeBreakDurationSeconds"
    static let standupBreakDurationMinutes = "standupBreakDurationMinutes"
    static let standupEveryEyeBreaks = "standupEveryEyeBreaks"
    static let maskOpacityPercent = "maskOpacityPercent"
    static let breakMessage = "breakMessage"
    static let enableGradualWakeUp = "enableGradualWakeUp"
    static let gradualWakeUpSeconds = "gradualWakeUpSeconds"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    /// 写入 AppleLanguages 的值；system 时返回 nil（跟随系统）
    var appleLanguagesValue: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        }
    }

    var displayName: String {
        switch self {
        case .system: NSLocalizedString("System", comment: "")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

enum LanguageManager {
    static var storedLanguage: AppLanguage {
        get {
            AppLanguage(rawValue: UserDefaults.standard.string(forKey: PreferencesKey.appLanguage) ?? AppLanguage.system.rawValue)
                ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: PreferencesKey.appLanguage)
        }
    }

    /// 启动时把已保存的语言偏好同步到 AppleLanguages
    static func applyStoredLanguage() {
        let language = storedLanguage
        if let value = language.appleLanguagesValue {
            UserDefaults.standard.set([value], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    /// 启动一个新实例并退出当前进程（语言切换需要重启生效）
    /// 通过独立 helper 延迟 0.5 秒重新打开，等当前进程完全退出，避免双实例并存。
    @MainActor
    static func relaunch() {
        let url = Bundle.main.bundleURL
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", "sleep 0.5; open \"$1\"", "relaunch", url.path]
        try? helper.run()
        NSApp.terminate(nil)
    }
}

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

    @AppStorage(PreferencesKey.appLanguage) private var appLanguageRaw = AppLanguage.system.rawValue

    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRaw) ?? .system }
        set { appLanguageRaw = newValue.rawValue }
    }

    @AppStorage(PreferencesKey.launchAtStartup) var launchAtStartup = false
    @AppStorage(PreferencesKey.showTimeInMenuBar) var showTimeInMenuBar = true
    @AppStorage(PreferencesKey.playSoundWhenBreakEnds) var playSoundWhenBreakEnds = true
    @AppStorage(PreferencesKey.fadeInMaskWindow) var fadeInMaskWindow = true
    @AppStorage(PreferencesKey.pauseWhenMouseInactive) var pauseWhenMouseInactive = false
    @AppStorage(PreferencesKey.mouseInactiveMinutes) var mouseInactiveMinutes = 5
    @AppStorage(PreferencesKey.enableStandupBreak) var enableStandupBreak = false

    @AppStorage(PreferencesKey.eyeBreakEveryMinutes) var eyeBreakEveryMinutes = 20
    @AppStorage(PreferencesKey.eyeBreakDurationSeconds) var eyeBreakDurationSeconds = 20
    @AppStorage(PreferencesKey.standupBreakDurationMinutes) var standupBreakDurationMinutes = 5
    @AppStorage(PreferencesKey.standupEveryEyeBreaks) var standupEveryEyeBreaks = 2

    @AppStorage(PreferencesKey.maskOpacityPercent) var maskOpacityPercent = 82
    @AppStorage(PreferencesKey.breakMessage) var breakMessage = NSLocalizedString("Time to take a break", comment: "")

    @AppStorage(PreferencesKey.enableGradualWakeUp) var enableGradualWakeUp = true
    @AppStorage(PreferencesKey.gradualWakeUpSeconds) var gradualWakeUpSeconds = 5

    private init() {}
}
