import SwiftUI

struct MainView: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var settings = settings
        let p = settings.palette(for: scheme)

        Group {
            if Visibility.shared.isVisible("main") {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        ClockFace(size: fittedSize(in: geo.size))
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .padding(24)

                    ThemeGallery()
                        .padding(.bottom, 18)
                }
            } else {
                // Window closed or hidden: release the clock views entirely.
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.background.ignoresSafeArea())
        .trackVisibility("main")
        .animation(.easeInOut(duration: 0.25), value: settings.config)
        .onAppear { AppActions.shared.openWindow = openWindow }
        .toolbar {
            ToolbarItemGroup {
                Picker("Appearance", selection: $settings.config.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Image(systemName: mode.symbol).help(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("Appearance: Light, Dark or follow System")

                Toggle(isOn: $settings.config.showSeconds) {
                    Label("Seconds", systemImage: "stopwatch")
                }
                .help("Show seconds")

                Toggle(isOn: $settings.config.widgetVisible) {
                    Label("Desktop Widget", systemImage: "macwindow.on.rectangle")
                }
                .help("Show the clock on your desktop")

                Button { openWindow(id: "alarms") } label: {
                    Label("Alarms", systemImage: "alarm")
                }
                .help("Alarms")

                Menu {
                    Button("Match Clock Theme") { SystemActions.themeWallpaper() }
                    Button("Choose Image…") { SystemActions.chooseWallpaper() }
                } label: {
                    Label("Wallpaper", systemImage: "photo.on.rectangle")
                }
                .help("Set desktop wallpaper")

                Menu {
                    Button("Turn Off Display") { SystemActions.sleepDisplay() }
                    Button("Start Screen Saver") { SystemActions.startScreenSaver() }
                    Button("Sleep Mac") { SystemActions.sleepMac() }
                } label: {
                    Label("Sleep", systemImage: "moon.zzz")
                } primaryAction: {
                    SystemActions.sleepDisplay()
                }
                .help("Click to turn off the display; hold for more")

                Button { openWindow(id: "settings") } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .help("Fonts, colors and more")
            }
        }
        .frame(minWidth: 700, minHeight: 440)
    }
}

extension MainView {
    /// The largest digit size whose face fits the space (one clock instead of
    /// several ViewThatFits candidates). Factors are each face's size in digit units.
    func fittedSize(in space: CGSize) -> CGFloat {
        let c = settings.config
        let dateH: CGFloat = c.showDate ? 0.6 : 0
        let w: CGFloat, h: CGFloat
        switch c.face {
        case .flip:
            let cards: CGFloat = c.showSeconds ? 3 : 2
            w = cards * 1.6 + (cards - 1) * 0.14
            h = 1.5 + dateH
        case .minimal:
            w = 3.9 + (c.showSeconds ? 0.75 : 0) + (c.use24h ? 0 : 0.45)
            h = 1.6 + dateH
        case .segment:
            w = 3.6 + (c.showSeconds ? 0.8 : 0) + (c.use24h ? 0 : 0.35)
            h = 1.6 + dateH * 0.6
        case .dotMatrix:
            w = 4.6 + (c.showSeconds || !c.use24h ? 1.2 : 0)
            h = 1.25 + dateH
        case .analog:
            w = 2.7
            h = 2.7 + dateH
        }
        return max(24, min(130, space.width / w, space.height / h) * 0.94)
    }
}

/// Clickable thumbnails of every face, plus a row of color swatches.
struct ThemeGallery: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = settings.palette(for: scheme)
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(FaceStyle.allCases) { style in
                    let selected = settings.config.face == style
                    Button {
                        settings.config.face = style
                    } label: {
                        VStack(spacing: 6) {
                            ClockFace(style: style, size: style == .analog ? 16 : 18, animated: false)
                                .frame(width: 124, height: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(p.digit.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(selected ? p.accent : p.digit.opacity(0.12), lineWidth: selected ? 2.5 : 1)
                                )
                            Text(style.title)
                                .font(.caption.weight(selected ? .semibold : .regular))
                                .foregroundStyle(p.digit.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            SwatchRow(config: Bindable(settings).config)
        }
    }
}

struct SwatchRow: View {
    @Binding var config: ClockConfig
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = config.palette(for: scheme)
        HStack(spacing: 10) {
            ForEach(ColorPreset.all) { preset in
                let c = (scheme == .dark ? preset.dark : preset.light).palette
                swatch(card: c.card, digit: c.digit, bg: c.background,
                       selected: config.presetID == preset.id, ring: p.accent)
                    .help(preset.name)
                    .onTapGesture { config.presetID = preset.id }
            }
            let custom = (scheme == .dark ? config.customDark : config.customLight).palette
            swatch(card: custom.card, digit: custom.digit, bg: custom.background,
                   selected: config.presetID == "custom", ring: p.accent)
                .overlay(Image(systemName: "paintpalette.fill").font(.system(size: 9)).foregroundStyle(custom.digit).offset(x: 9, y: 9))
                .help("Custom colors (edit in Settings)")
                .onTapGesture { config.presetID = "custom" }
        }
    }

    private func swatch(card: Color, digit: Color, bg: Color, selected: Bool, ring: Color) -> some View {
        ZStack {
            Circle().fill(bg)
            Circle().fill(card).padding(4)
            Text("8").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(digit)
        }
        .frame(width: 28, height: 28)
        .overlay(Circle().strokeBorder(selected ? ring : .gray.opacity(0.35), lineWidth: selected ? 2.5 : 1))
        .contentShape(Circle())
    }
}
