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

                    Text("\(preferences.gradualWakeUpSeconds) seconds")
                        .monospacedDigit()
                        .frame(width: 70, alignment: .leading)
                }
            }

            Divider()

            Toggle("Pause when mouse inactive for 5 mins", isOn: $preferences.pauseWhenMouseInactive)
            Toggle("Enable standup break", isOn: $preferences.enableStandupBreak)
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 14))
        .padding(.top, 20)
        .padding(.leading, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var launchBinding: Binding<Bool> {
        Binding {
            preferences.launchAtStartup
        } set: { newValue in
            preferences.launchAtStartup = newValue
            updateLoginItem(enabled: newValue)
        }
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
                ScheduleRow(label: "Every", value: $preferences.eyeBreakEveryMinutes, range: 1...180, unit: "mins")
                ScheduleRow(label: "Break for", value: $preferences.eyeBreakDurationSeconds, range: 5...600, unit: "seconds")
            }
            .font(.system(size: 14))
        } else {
            VStack(spacing: 10) {
                ScheduleRow(label: "Break for", value: $preferences.standupBreakDurationMinutes, range: 1...60, unit: "mins")
                ScheduleRow(label: "Every", value: $preferences.standupEveryEyeBreaks, range: 1...24, unit: "eye breaks")
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
                Text("\(preferences.maskOpacityPercent)%")
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
            Text("Version 1.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
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
