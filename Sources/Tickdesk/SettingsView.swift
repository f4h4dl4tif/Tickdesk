import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            tabs
            Divider()
            SaveBar()
        }
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .trackVisibility("settings")
    }

    private var tabs: some View {
        TabView {
            AppearanceSettings().tabItem { Label("Appearance", systemImage: "paintbrush") }
            ClockSettingsTab().tabItem { Label("Clock", systemImage: "clock") }
            WidgetSettings().tabItem { Label("Widget", systemImage: "macwindow.on.rectangle") }
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
        }
    }
}

/// Changes in Settings are a draft; nothing reaches the clock or widget until Save.
private struct SaveBar: View {
    @Environment(ClockSettings.self) private var settings

    var body: some View {
        let dirty = settings.hasUnsavedChanges
        HStack(spacing: 10) {
            if dirty {
                Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.orange)
                Text("Unsaved changes. The preview shows them; click Save to apply them.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("All changes saved").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Revert") { settings.revertDraft() }
                .disabled(!dirty)
                .keyboardShortcut(.cancelAction)
                .glassButton(settings.config.usesGlass)
            Button("Save") { settings.saveDraft() }
                .disabled(!dirty)
                .keyboardShortcut("s", modifiers: .command)
                .glassButton(settings.config.usesGlass, prominent: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.15), value: dirty)
    }
}

private struct PreviewHeader: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    /// The preview follows the unsaved Light/Dark/System choice too.
    private var previewScheme: ColorScheme {
        switch settings.draft.appearance {
        case .light: return .light
        case .dark: return .dark
        case .system:
            return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
        }
    }

    var body: some View {
        ClockFace(size: 34, showsBackground: true)
            .environment(\.previewConfig, settings.draft)
            .environment(\.colorScheme, previewScheme)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .padding(.vertical, 4)
            .background {
                // Glass needs something behind it to show; plain keeps the form background.
                if settings.draft.usesGlass {
                    GlassBackdrop(p: settings.draft.palette(for: previewScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(-6)
                }
            }
    }
}

private struct AppearanceSettings: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var settings = settings
        Form {
            PreviewHeader()

            Section("Theme") {
                Picker("Appearance", selection: $settings.draft.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text("System follows macOS Light/Dark mode automatically, including Auto at sunset.")
                    .font(.caption).foregroundStyle(.secondary)

                GlassThemeToggle(isOn: $settings.draft.glassTheme)

                Picker("Clock style", selection: $settings.draft.face) {
                    ForEach(FaceStyle.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Font") {
                Picker("Font style", selection: $settings.draft.font) {
                    ForEach(FontStyle.allCases) { f in
                        Text("12:34  \(f.title)").font(f.font(size: 13, weight: .medium)).tag(f)
                    }
                }
                Picker("Weight", selection: $settings.draft.weight) {
                    ForEach(FontWeightOption.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Colors") {
                LabeledContent("Combination") { SwatchRow(config: $settings.draft) }
                Picker("Preset", selection: $settings.draft.presetID) {
                    ForEach(ColorPreset.all) { Text($0.name).tag($0.id) }
                    Divider()
                    Text("Custom").tag("custom")
                }
                if settings.draft.presetID == "custom" {
                    CustomColorEditor(title: "Light mode colors", colors: $settings.draft.customLight)
                    CustomColorEditor(title: "Dark mode colors", colors: $settings.draft.customDark)
                } else {
                    Button("Customize These Colors…") { settings.draft.beginCustomizing() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct CustomColorEditor: View {
    let title: String
    @Binding var colors: CustomColors

    private func binding(_ kp: WritableKeyPath<CustomColors, String>) -> Binding<Color> {
        Binding(get: { Color(hex: colors[keyPath: kp]) },
                set: { colors[keyPath: kp] = $0.hexString })
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 14) {
                ColorPicker("Background", selection: binding(\.background), supportsOpacity: false)
                ColorPicker("Card", selection: binding(\.card), supportsOpacity: false)
                ColorPicker("Digits", selection: binding(\.digit), supportsOpacity: false)
                ColorPicker("Accent", selection: binding(\.accent), supportsOpacity: false)
            }
            .labelsHidden()
        }
        .help("Background · Card · Digits · Accent")
        HStack {
            Spacer()
            Text("Background · Card · Digits · Accent").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct ClockSettingsTab: View {
    @Environment(ClockSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            PreviewHeader()
            Section("Time") {
                Picker("Format", selection: $settings.draft.use24h) {
                    Text("24-hour").tag(true)
                    Text("12-hour (AM/PM)").tag(false)
                }
                .pickerStyle(.segmented)
                Toggle("Show seconds", isOn: $settings.draft.showSeconds)
                Toggle("Blink colon", isOn: $settings.draft.blinkColon)
            }
            Section("Date") {
                Toggle("Show date", isOn: $settings.draft.showDate)
                Picker("Date format", selection: $settings.draft.dateStyle) {
                    ForEach(DateStyleOption.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!settings.draft.showDate)
            }
        }
        .formStyle(.grouped)
    }
}

private struct WidgetSettings: View {
    @Environment(ClockSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Desktop widget") {
                Toggle("Show clock on desktop", isOn: $settings.draft.widgetVisible)
                Picker("Style", selection: $settings.draft.widgetFace) {
                    Text("Same as main clock").tag(FaceStyle?.none)
                    ForEach(FaceStyle.allCases) { Text($0.title).tag(FaceStyle?.some($0)) }
                }
                Picker("Position", selection: $settings.draft.widgetLevel) {
                    ForEach(WidgetLevel.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Size") {
                    Slider(value: $settings.draft.widgetScale, in: 0.5...2.5) {
                        EmptyView()
                    } minimumValueLabel: { Image(systemName: "textformat.size.smaller") }
                      maximumValueLabel: { Image(systemName: "textformat.size.larger") }
                }
                LabeledContent("Opacity") {
                    Slider(value: $settings.draft.widgetOpacity, in: 0.2...1)
                }
                Toggle("Show background panel", isOn: $settings.draft.widgetBackground)
                Toggle("Lock position", isOn: $settings.draft.widgetLocked)
            }
            Text("Drag the widget to move it. Right-click it for quick options.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct GeneralSettings: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open Tickdesk at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }))
            }
            Section("Quick actions") {
                LabeledContent("Alarms") { Button("Manage Alarms…") { openWindow(id: "alarms") } }
                LabeledContent("Wallpaper") {
                    HStack {
                        Button("Match Clock Theme") { SystemActions.themeWallpaper() }
                        Button("Choose Image…") { SystemActions.chooseWallpaper() }
                    }
                }
                LabeledContent("Sleep") {
                    HStack {
                        Button("Display Off") { SystemActions.sleepDisplay() }
                        Button("Screen Saver") { SystemActions.startScreenSaver() }
                        Button("Sleep Mac") { SystemActions.sleepMac() }
                    }
                }
            }
            Section {
                Button("Reset All Settings to Defaults", role: .destructive) { settings.draft = ClockConfig() }
            }
        }
        .formStyle(.grouped)
    }
}
