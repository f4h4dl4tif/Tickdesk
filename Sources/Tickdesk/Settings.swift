import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Options

enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum FaceStyle: String, CaseIterable, Identifiable, Codable {
    case flip, minimal, segment, dotMatrix, analog
    var id: String { rawValue }
    var title: String {
        switch self {
        case .flip: "Flip Cards"
        case .minimal: "Minimal"
        case .segment: "LCD Segment"
        case .dotMatrix: "Dot Matrix"
        case .analog: "Analog"
        }
    }
}

enum FontStyle: String, CaseIterable, Identifiable, Codable {
    case rounded, sfPro, mono, serif, avenir, futura, din, helvetica, gillSans, didot, georgia, menlo, courier, typewriter

    var id: String { rawValue }
    var title: String {
        switch self {
        case .rounded: "SF Rounded"
        case .sfPro: "SF Pro"
        case .mono: "SF Mono"
        case .serif: "New York (Serif)"
        case .avenir: "Avenir Next"
        case .futura: "Futura"
        case .din: "DIN Alternate"
        case .helvetica: "Helvetica Neue"
        case .gillSans: "Gill Sans"
        case .didot: "Didot"
        case .georgia: "Georgia"
        case .menlo: "Menlo"
        case .courier: "Courier New"
        case .typewriter: "American Typewriter"
        }
    }
    private var familyName: String? {
        switch self {
        case .rounded, .sfPro, .mono, .serif: nil
        case .avenir: "Avenir Next"
        case .futura: "Futura"
        case .din: "DIN Alternate"
        case .helvetica: "Helvetica Neue"
        case .gillSans: "Gill Sans"
        case .didot: "Didot"
        case .georgia: "Georgia"
        case .menlo: "Menlo"
        case .courier: "Courier New"
        case .typewriter: "American Typewriter"
        }
    }
    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .sfPro: return .system(size: size, weight: weight, design: .default)
        case .mono: return .system(size: size, weight: weight, design: .monospaced)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        default: return Font.custom(familyName ?? "Helvetica", size: size).weight(weight)
        }
    }
}

enum FontWeightOption: String, CaseIterable, Identifiable, Codable {
    case thin, light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var weight: Font.Weight {
        switch self {
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

enum DateStyleOption: String, CaseIterable, Identifiable, Codable {
    case long, short, compact, numeric
    var id: String { rawValue }
    var title: String {
        switch self {
        case .long: "Friday, November 20"
        case .short: "Fri, Nov 20"
        case .compact: "Fri 20 Nov 2026"
        case .numeric: "2026/11/20"
        }
    }
    private static var cache: [DateStyleOption: DateFormatter] = [:]
    func format(_ date: Date) -> String {
        if let f = Self.cache[self] { return f.string(from: date) }
        let f = DateFormatter()
        switch self {
        case .long: f.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        case .short: f.setLocalizedDateFormatFromTemplate("EEEMMMd")
        case .compact: f.dateFormat = "EEE d MMM yyyy"
        case .numeric: f.dateFormat = "yyyy/MM/dd"
        }
        Self.cache[self] = f
        return f.string(from: date)
    }
}

enum WidgetLevel: String, CaseIterable, Identifiable, Codable {
    case desktop, normal, floating
    var id: String { rawValue }
    var title: String {
        switch self {
        case .desktop: "On desktop (behind windows)"
        case .normal: "Normal window"
        case .floating: "Always on top"
        }
    }
    var windowLevel: NSWindow.Level {
        switch self {
        case .desktop: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .normal: .normal
        case .floating: .floating
        }
    }
}

// MARK: - Colors

struct Palette: Equatable {
    var background: Color
    var card: Color
    var digit: Color
    var accent: Color
}

struct CustomColors: Codable, Equatable {
    var background: String
    var card: String
    var digit: String
    var accent: String
    var palette: Palette {
        Palette(background: Color(hex: background), card: Color(hex: card), digit: Color(hex: digit), accent: Color(hex: accent))
    }
}

struct ColorPreset: Identifiable {
    let id: String
    let name: String
    let light: CustomColors
    let dark: CustomColors

    static let all: [ColorPreset] = [
        ColorPreset(id: "classic", name: "Classic",
                    light: .init(background: "#E9E9EC", card: "#FFFFFF", digit: "#1C1C1E", accent: "#FF3B30"),
                    dark: .init(background: "#101012", card: "#2A2A2D", digit: "#F5F5F7", accent: "#FF453A")),
        ColorPreset(id: "ink", name: "Ink",
                    light: .init(background: "#E4E6EB", card: "#1C1C1E", digit: "#FFFFFF", accent: "#FF9F0A"),
                    dark: .init(background: "#000000", card: "#151517", digit: "#EDEDED", accent: "#FF9F0A")),
        ColorPreset(id: "midnight", name: "Midnight",
                    light: .init(background: "#DCE3F2", card: "#24325A", digit: "#FFFFFF", accent: "#5AC8FA"),
                    dark: .init(background: "#0A0F1F", card: "#1A2444", digit: "#DCE6FF", accent: "#64D2FF")),
        ColorPreset(id: "lavender", name: "Lavender",
                    light: .init(background: "#E3E2F5", card: "#F7F6FF", digit: "#4B4A8C", accent: "#AF52DE"),
                    dark: .init(background: "#16152B", card: "#2B2950", digit: "#D9D7FF", accent: "#BF5AF2")),
        ColorPreset(id: "lcd", name: "Retro LCD",
                    light: .init(background: "#DCE3D2", card: "#B7C6A2", digit: "#1E2A17", accent: "#3C5A2A"),
                    dark: .init(background: "#0E120C", card: "#1C2418", digit: "#B9F27C", accent: "#7DD13F")),
        ColorPreset(id: "neon", name: "Neon",
                    light: .init(background: "#E7F7F4", card: "#0D1B1E", digit: "#3DFFD0", accent: "#FF2D95"),
                    dark: .init(background: "#05080A", card: "#0D1416", digit: "#3DFFD0", accent: "#FF2D95")),
        ColorPreset(id: "sunset", name: "Sunset",
                    light: .init(background: "#FBE6D8", card: "#FFF6EF", digit: "#C2410C", accent: "#F97316"),
                    dark: .init(background: "#1E0F0A", card: "#3A1D12", digit: "#FFB98A", accent: "#FB923C")),
        ColorPreset(id: "forest", name: "Forest",
                    light: .init(background: "#E1ECE3", card: "#FFFFFF", digit: "#1F5134", accent: "#34C759"),
                    dark: .init(background: "#0B1610", card: "#173323", digit: "#CDEFD8", accent: "#30D158")),
        ColorPreset(id: "rose", name: "Rose",
                    light: .init(background: "#F8E4E8", card: "#FFFFFF", digit: "#9F1D47", accent: "#FF375F"),
                    dark: .init(background: "#1A0B10", card: "#3A1422", digit: "#FFC9D7", accent: "#FF375F")),
        ColorPreset(id: "wood", name: "Walnut",
                    light: .init(background: "#EFE6DA", card: "#C9A57A", digit: "#3B2614", accent: "#8B5A2B"),
                    dark: .init(background: "#15100B", card: "#4A3320", digit: "#F2DEC4", accent: "#D19A5B")),
    ]
}

// MARK: - Config

struct ClockConfig: Codable, Equatable {
    var appearance: AppearanceMode = .system
    var face: FaceStyle = .flip
    var presetID: String = "classic"
    var font: FontStyle = .rounded
    var weight: FontWeightOption = .bold
    var customLight = CustomColors(background: "#E9E9EC", card: "#FFFFFF", digit: "#1C1C1E", accent: "#FF3B30")
    var customDark = CustomColors(background: "#101012", card: "#2A2A2D", digit: "#F5F5F7", accent: "#FF453A")
    var use24h = true
    var showSeconds = true
    var showDate = true
    var blinkColon = true
    var dateStyle: DateStyleOption = .long
    var widgetVisible = true
    var widgetFace: FaceStyle? = nil
    var widgetLevel: WidgetLevel = .desktop
    var widgetScale: Double = 1.0
    var widgetOpacity: Double = 1.0
    var widgetBackground = false
    var widgetLocked = false
}

@Observable
@MainActor
final class ClockSettings {
    static let shared = ClockSettings()
    private static let key = "Tickdesk.config.v1"

    var config: ClockConfig {
        didSet {
            guard config != oldValue else { return }
            // Quick toggles (toolbar, menu bar, widget menu) apply instantly; keep the
            // Settings draft in step with them unless the user has unsaved edits.
            if draft == oldValue { draft = config }
            save()
            if config.appearance != oldValue.appearance { applyAppearance() }
            DesktopWidgetController.shared.sync()
        }
    }

    /// Edits made in the Settings window. They only take effect when saved.
    var draft: ClockConfig

    var hasUnsavedChanges: Bool { draft != config }

    func saveDraft() { config = draft }
    func revertDraft() { draft = config }

    private init() {
        let loaded: ClockConfig
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(ClockConfig.self, from: data) {
            loaded = decoded
        } else {
            loaded = ClockConfig()
        }
        config = loaded
        draft = loaded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func applyAppearance() {
        NSApp.appearance = config.appearance.nsAppearance
    }

    func palette(for scheme: ColorScheme) -> Palette { config.palette(for: scheme) }

    func font(_ size: CGFloat, weight: Font.Weight? = nil) -> Font {
        config.typeface(size, weight: weight)
    }

    var effectiveScheme: ColorScheme {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? .dark : .light
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Tickdesk: launch at login change failed: \(error)")
            }
        }
    }
}

extension ClockConfig {
    func colors(for scheme: ColorScheme) -> CustomColors {
        if presetID == "custom" {
            return scheme == .dark ? customDark : customLight
        }
        let preset = ColorPreset.all.first { $0.id == presetID } ?? ColorPreset.all[0]
        return scheme == .dark ? preset.dark : preset.light
    }

    func palette(for scheme: ColorScheme) -> Palette { colors(for: scheme).palette }

    func typeface(_ size: CGFloat, weight: Font.Weight? = nil) -> Font {
        font.font(size: size, weight: weight ?? self.weight.weight)
    }

    /// Copies the active preset into the custom slots so the user can tweak it.
    mutating func beginCustomizing() {
        guard presetID != "custom" else { return }
        customLight = colors(for: .light)
        customDark = colors(for: .dark)
        presetID = "custom"
    }
}

/// Lets a view (the Settings preview) render a config other than the saved one.
private struct PreviewConfigKey: EnvironmentKey {
    static let defaultValue: ClockConfig? = nil
}

extension EnvironmentValues {
    var previewConfig: ClockConfig? {
        get { self[PreviewConfigKey.self] }
        set { self[PreviewConfigKey.self] = newValue }
    }
}

// MARK: - Helpers

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 6 { s += "FF" }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 24) & 0xFF) / 255,
                  green: Double((v >> 16) & 0xFF) / 255,
                  blue: Double((v >> 8) & 0xFF) / 255,
                  opacity: Double(v & 0xFF) / 255)
    }

    var hexString: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}
