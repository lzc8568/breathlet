import Foundation
import SwiftUI

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
            AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue)
                ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
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
    @MainActor
    static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        try? process.run()
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

    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue

    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRaw) ?? .system }
        set { appLanguageRaw = newValue.rawValue }
    }

    @AppStorage("launchAtStartup") var launchAtStartup = false
    @AppStorage("showTimeInMenuBar") var showTimeInMenuBar = true
    @AppStorage("playSoundWhenBreakEnds") var playSoundWhenBreakEnds = true
    @AppStorage("fadeInMaskWindow") var fadeInMaskWindow = true
    @AppStorage("pauseWhenMouseInactive") var pauseWhenMouseInactive = false
    @AppStorage("mouseInactiveMinutes") var mouseInactiveMinutes = 5
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
