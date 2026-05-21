import ServiceManagement
import SwiftUI

enum PreferencesWindowMetrics {
    static let width: CGFloat = 900
    static let height: CGFloat = 430
}

struct PreferencesView: View {
    @EnvironmentObject private var preferences: Preferences
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

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
        .frame(width: PreferencesWindowMetrics.width, height: PreferencesWindowMetrics.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        VStack(spacing: 6) {
            Text(pageTitle)
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 8)

            HStack(spacing: 2) {
                toolbarButton(index: 0, title: "General", symbol: "switch.2")
                toolbarButton(index: 1, title: "Break", symbol: "gearshape")
                toolbarButton(index: 2, title: "About", symbol: "info.circle.fill")
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    private var pageTitle: String {
        switch page {
        case 0: "General"
        case 1: "Break"
        default: "About"
        }
    }

    private func toolbarButton(index: Int, title: String, symbol: String) -> some View {
        Button {
            page = index
        } label: {
            VStack(spacing: 1) {
                Image(systemName: symbol)
                    .font(.system(size: 32))
                    .symbolRenderingMode(index == 2 ? .palette : .monochrome)
                    .foregroundStyle(index == 2 ? .white : .secondary, index == 2 ? .blue : .secondary)
                    .frame(width: 44, height: 38)

                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(page == index ? .blue : .secondary)
            }
            .frame(width: 78, height: 64)
            .background(page == index ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct GeneralPreferencesView: View {
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Launch at system startup", isOn: launchBinding)
            Toggle("Show time in Menu Bar", isOn: $preferences.showTimeInMenuBar)
            Toggle("Play sound when break ends", isOn: $preferences.playSoundWhenBreakEnds)
            Toggle("Fade in mask window", isOn: $preferences.fadeInMaskWindow)
            Toggle("Pause when mouse inactive for 5 mins", isOn: $preferences.pauseWhenMouseInactive)
            Toggle("Enable standup break", isOn: $preferences.enableStandupBreak)
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 17))
        .padding(.top, 34)
        .padding(.leading, 116)
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
        HStack(spacing: 16) {
            breakList

            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(BreakSettingsTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                .padding(.top, -20)
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
        .padding(28)
    }

    private var breakList: some View {
        List(selection: $selectedBreak) {
            Section("Breaks") {
                ForEach(BreakKind.allCases) { kind in
                    Text(kind.title)
                        .tag(kind)
                        .font(.system(size: 17))
                }
            }
        }
        .listStyle(.inset)
        .frame(width: 210)
        .clipShape(Rectangle())
        .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
    }

    @ViewBuilder
    private var scheduleContent: some View {
        if selectedBreak == .eye {
            VStack(spacing: 14) {
                ScheduleRow(label: "Every", value: $preferences.eyeBreakEveryMinutes, range: 1...180, unit: "mins")
                ScheduleRow(label: "Break for", value: $preferences.eyeBreakDurationSeconds, range: 5...600, unit: "seconds")
            }
            .font(.system(size: 17))
        } else {
            VStack(spacing: 14) {
                ScheduleRow(label: "Break for", value: $preferences.standupBreakDurationMinutes, range: 1...60, unit: "mins")
                ScheduleRow(label: "Every", value: $preferences.standupEveryEyeBreaks, range: 1...24, unit: "eye breaks")
            }
            .font(.system(size: 17))
        }
    }

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Mask opacity")
                Slider(value: Binding(
                    get: { Double(preferences.maskOpacityPercent) },
                    set: { preferences.maskOpacityPercent = Int($0) }
                ), in: 30...95, step: 1)
                .frame(width: 220)
                Text("\(preferences.maskOpacityPercent)%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }

            HStack {
                Text("Message")
                TextField("Break message", text: $preferences.breakMessage)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 290)
            }
        }
        .font(.system(size: 17))
    }

}

private struct ScheduleRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .frame(width: 86, alignment: .trailing)

            StepperTextField(value: $value, range: range)

            Text(unit)
                .frame(width: 90, alignment: .leading)
        }
        .frame(width: 374, alignment: .leading)
    }
}

private struct AboutPreferencesView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 54))
                .foregroundStyle(.blue)
            Text("Take a Break")
                .font(.title.bold())
            Text("A tiny menu bar reminder to rest your eyes during focused work.")
                .foregroundStyle(.secondary)
            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

private struct StepperTextField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        TextField("", value: clampedValue, format: .number)
            .textFieldStyle(.plain)
            .font(.system(size: 17))
            .padding(.horizontal, 8)
            .frame(width: 170, height: 28)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
    }

    private var clampedValue: Binding<Int> {
        Binding {
            value
        } set: { newValue in
            value = min(max(newValue, range.lowerBound), range.upperBound)
        }
    }
}
