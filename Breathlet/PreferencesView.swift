import AppKit
import ServiceManagement
import SwiftUI

enum PreferencesWindowMetrics {
    static let width: CGFloat = 720
    static let height: CGFloat = 480
}

struct PreferencesView: View {
    @EnvironmentObject private var preferences: Preferences
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            Group {
                switch page {
                case 0:
                    GeneralPreferencesView()
                        .environmentObject(preferences)
                case 1:
                    BreakPreferencesView()
                        .environmentObject(preferences)
                default:
                    AboutPreferencesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: PreferencesWindowMetrics.width, height: PreferencesWindowMetrics.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            toolbarButton(index: 0, title: "General", symbol: "switch.2")
            toolbarButton(index: 1, title: "Break", symbol: "gearshape")
            toolbarButton(index: 2, title: "About", symbol: "info.circle.fill")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .background(.regularMaterial)
    }

    private func toolbarButton(index: Int, title: String, symbol: String) -> some View {
        Button {
            page = index
        } label: {
            VStack(spacing: 1) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .symbolRenderingMode(index == 2 ? .palette : .monochrome)
                    .foregroundStyle(index == 2 ? .white : .secondary, index == 2 ? .blue : .secondary)
                    .frame(width: 32, height: 28)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(page == index ? .blue : .secondary)
            }
            .frame(width: 64, height: 48)
            .background(page == index ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

private struct GeneralPreferencesView: View {
    @EnvironmentObject private var preferences: Preferences
    @State private var showRestartAlert = false
    @State private var pendingLanguage: AppLanguage = .system

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at system startup", isOn: launchBinding)
            Toggle("Show time in Menu Bar", isOn: $preferences.showTimeInMenuBar)
            Toggle("Play sound when break ends", isOn: $preferences.playSoundWhenBreakEnds)
            Toggle("Fade in mask window", isOn: $preferences.fadeInMaskWindow)

            Divider()

            HStack(spacing: 12) {
                Toggle("Enable gradual wake-up fade", isOn: $preferences.enableGradualWakeUp)

                if preferences.enableGradualWakeUp {
                    Text("Fade duration")

                    Slider(value: Binding(
                        get: { Double(preferences.gradualWakeUpSeconds) },
                        set: { preferences.gradualWakeUpSeconds = Int($0) }
                    ), in: 1...10, step: 1)
                    .frame(width: 120)

                    Text(String(
                        format: NSLocalizedString("%d seconds", comment: ""),
                        preferences.gradualWakeUpSeconds
                    ))
                        .monospacedDigit()
                        .frame(width: 70, alignment: .leading)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Toggle("Pause when mouse inactive", isOn: $preferences.pauseWhenMouseInactive)

                if preferences.pauseWhenMouseInactive {
                    StepperTextField(value: $preferences.mouseInactiveMinutes, range: 1...60)

                    Text("mins")
                        .monospacedDigit()
                }
            }
            Toggle("Enable standup break", isOn: $preferences.enableStandupBreak)

            Divider()

            HStack(spacing: 12) {
                Text("Language")
                Spacer()
                Picker("", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 14))
        .padding(.top, 20)
        .padding(.leading, 80)
        .padding(.trailing, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(NSLocalizedString("Restart required", comment: ""), isPresented: $showRestartAlert) {
            Button(NSLocalizedString("Restart Now", comment: "")) {
                applyAndRelaunch()
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("The language change will take effect after restart.", comment: ""))
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding {
            preferences.launchAtStartup
        } set: { newValue in
            preferences.launchAtStartup = newValue
            updateLoginItem(enabled: newValue)
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding {
            preferences.appLanguage
        } set: { newValue in
            guard newValue != preferences.appLanguage else { return }
            pendingLanguage = newValue
            showRestartAlert = true
        }
    }

    private func applyAndRelaunch() {
        preferences.appLanguage = pendingLanguage
        LanguageManager.storedLanguage = pendingLanguage
        LanguageManager.applyStoredLanguage()
        LanguageManager.relaunch()
    }

    private func updateLoginItem(enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            preferences.launchAtStartup = false
        }
    }
}

private struct BreakPreferencesView: View {
    @EnvironmentObject private var preferences: Preferences
    @State private var selectedBreak: BreakKind = .eye
    @State private var selectedTab: BreakSettingsTab = .schedule

    var body: some View {
        HStack(spacing: 12) {
            breakList

            VStack(spacing: 6) {
                Picker("", selection: $selectedTab) {
                    ForEach(BreakSettingsTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .zIndex(1)

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor))
                        )

                    if selectedTab == .schedule {
                        scheduleContent
                    } else {
                        appearanceContent
                    }

                }
            }
        }
        .padding(16)
    }

    private var breakList: some View {
        List(selection: $selectedBreak) {
            Section("Breaks") {
                ForEach(BreakKind.allCases) { kind in
                    Text(kind.title)
                        .tag(kind)
                        .font(.system(size: 14))
                }
            }
        }
        .listStyle(.inset)
        .frame(width: 140)
        .clipShape(Rectangle())
        .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
    }

    @ViewBuilder
    private var scheduleContent: some View {
        if selectedBreak == .eye {
            VStack(spacing: 10) {
                ScheduleRow(
                    label: NSLocalizedString("Every", comment: ""),
                    value: $preferences.eyeBreakEveryMinutes,
                    range: 1...180,
                    unit: NSLocalizedString("mins", comment: "")
                )
                ScheduleRow(
                    label: NSLocalizedString("Break for", comment: ""),
                    value: $preferences.eyeBreakDurationSeconds,
                    range: 5...600,
                    unit: NSLocalizedString("seconds", comment: "")
                )
            }
            .font(.system(size: 14))
        } else {
            VStack(spacing: 10) {
                ScheduleRow(
                    label: NSLocalizedString("Break for", comment: ""),
                    value: $preferences.standupBreakDurationMinutes,
                    range: 1...60,
                    unit: NSLocalizedString("mins", comment: "")
                )
                ScheduleRow(
                    label: NSLocalizedString("Every", comment: ""),
                    value: $preferences.standupEveryEyeBreaks,
                    range: 1...24,
                    unit: NSLocalizedString("eye breaks", comment: "")
                )
            }
            .font(.system(size: 14))
        }
    }

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mask opacity")
                Slider(value: Binding(
                    get: { Double(preferences.maskOpacityPercent) },
                    set: { preferences.maskOpacityPercent = Int($0) }
                ), in: 30...95, step: 1)
                .frame(width: 160)
                Text(String(
                    format: NSLocalizedString("%d%%", comment: ""),
                    preferences.maskOpacityPercent
                ))
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Text("Message")
                TextField("Break message", text: $preferences.breakMessage)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
        }
        .font(.system(size: 14))
    }

}

private struct ScheduleRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .frame(width: 72, alignment: .trailing)

            StepperTextField(value: $value, range: range)

            Text(unit)
                .frame(width: 74, alignment: .leading)
        }
        .frame(width: 320, alignment: .leading)
    }
}

private struct AboutPreferencesView: View {
    @State private var updateState: UpdateCheckState = .idle
    @ObservedObject private var updateModel = UpdateDownloader.shared.model

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
            Text("Breathlet")
                .font(.title3.bold())
            Text("A tiny menu bar reminder to rest your eyes during focused work.")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            Text(String(
                format: NSLocalizedString("Version %@", comment: ""),
                currentVersion
            ))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 260)

            updateSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    @ViewBuilder
    private var updateSection: some View {
        switch updateState {
        case .idle:
            Button("Check for Updates") {
                checkForUpdates()
            }
        case .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates…")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13))
        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(String(
                    format: NSLocalizedString("You're up to date (v%@)", comment: ""),
                    currentVersion
                ))
            }
            .font(.system(size: 13))
        case .updateAvailable(let info):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Text(String(
                        format: NSLocalizedString("v%@ is available", comment: ""),
                        info.version
                    ))
                }
                .font(.system(size: 13))

                switch updateModel.state {
                case .idle:
                    Button {
                        guard let url = URL(string: info.url) else { return }
                        UpdateDownloader.shared.start(from: url, version: info.version, sha256: info.sha256)
                    } label: {
                        Text(String(
                            format: NSLocalizedString("Download v%@", comment: ""),
                            info.version
                        ))
                    }
                case .downloading(let progress):
                    VStack(spacing: 4) {
                        ProgressView(value: progress)
                            .frame(width: 220)
                        Text(String(
                            format: NSLocalizedString("Downloading… %d%%", comment: ""),
                            Int(progress * 100)
                        ))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                case .downloaded(let url):
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Downloaded")
                        }
                        .font(.system(size: 13))

                        Button("Open DMG") {
                            NSWorkspace.shared.open(url)
                        }
                        .font(.system(size: 12))
                    }
                case .failed(let message):
                    VStack(spacing: 6) {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Button("Retry Download") {
                            guard let url = URL(string: info.url) else { return }
                            UpdateDownloader.shared.start(from: url, version: info.version, sha256: info.sha256)
                        }
                        .font(.system(size: 12))
                    }
                }
            }
        case .failed(let message):
            VStack(spacing: 8) {
                Text(message)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Button("Retry") {
                    checkForUpdates()
                }
            }
        }
    }

    private func checkForUpdates() {
        UpdateDownloader.shared.reset()
        updateState = .checking
        Task {
            do {
                let info = try await UpdateChecker.checkLatest()
                if UpdateChecker.isNewer(info.version, than: currentVersion) {
                    updateState = .updateAvailable(info)
                } else {
                    updateState = .upToDate
                }
            } catch {
                updateState = .failed("Unable to check for updates. Please try again.")
            }
        }
    }
}

private struct StepperTextField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    @State private var text = ""

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 6)
            .frame(width: 140, height: 24)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
            .onAppear {
                text = "\(value)"
            }
            .onChange(of: text) { newText in
                guard let newValue = Int(newText) else { return }
                value = min(max(newValue, range.lowerBound), range.upperBound)
            }
            .onChange(of: value) { newValue in
                guard Int(text) != newValue else { return }
                text = "\(newValue)"
            }
            .onSubmit {
                guard let newValue = Int(text) else {
                    text = "\(value)"
                    return
                }
                let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
                value = clampedValue
                text = "\(clampedValue)"
            }
    }
}
