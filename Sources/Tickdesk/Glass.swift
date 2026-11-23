import SwiftUI
import AppKit

// MARK: - Liquid Glass theme (shared design with Calendesk; keep the two files in step)

enum GlassSupport {
    /// Liquid Glass needs macOS 26 or later; older systems keep the solid look.
    static var isAvailable: Bool {
        if #available(macOS 26, *) { return true } else { return false }
    }
}

/// True for views drawn on top of a glass surface, so they don't stack glass on glass.
private struct OnGlassKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onGlass: Bool {
        get { self[OnGlassKey.self] }
        set { self[OnGlassKey.self] = newValue }
    }
}

extension Color {
    /// Relative luminance (0 = black, 1 = white).
    var luminance: Double {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return 0.5 }
        func lin(_ v: CGFloat) -> Double {
            let v = Double(v)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
    }
}

extension Palette {
    /// Glass is tinted with the card color and takes its light/dark material from it,
    /// so the text color chosen for the card stays legible over any wallpaper.
    var glassScheme: ColorScheme { card.luminance < 0.25 ? .dark : .light }

    /// Strength of the card-color tint on glass.
    var glassTint: Color { card.opacity(glassScheme == .dark ? 0.72 : 0.6) }

    /// Card-color layer over the glass.
    var glassWash: Color { card.opacity(glassScheme == .dark ? 0.5 : 0.3) }

    /// Fill for a group drawn on top of a glass panel (instead of glass on glass).
    var glassInset: Color { glassScheme == .dark ? digit.opacity(0.07) : card.opacity(0.5) }
}

/// Soft color field behind glass inside a window, so the glass has something to refract.
struct GlassBackdrop: View {
    let p: Palette
    var body: some View {
        GeometryReader { g in
            let r = max(g.size.width, g.size.height)
            ZStack {
                p.background
                RadialGradient(colors: [p.accent.opacity(0.30), p.accent.opacity(0)],
                               center: .topLeading, startRadius: 0, endRadius: r * 0.75)
                RadialGradient(colors: [p.accent.opacity(0.22), p.accent.opacity(0)],
                               center: .bottomTrailing, startRadius: 0, endRadius: r * 0.7)
                    .hueRotation(.degrees(70))
            }
        }
    }
}

extension View {
    /// A floating surface: the solid `fill` (with its soft shadow) normally, or
    /// Liquid Glass tinted with the palette's card color when `glass` is on.
    @ViewBuilder
    func surface<S: Shape>(_ shape: S, fill: Color, glass: Bool, palette p: Palette,
                           shadow: CGFloat = 0, shadowY: CGFloat = 0, shadowOpacity: Double = 0.14,
                           interactive: Bool = false) -> some View {
        if glass, #available(macOS 26, *) {
            self
                .environment(\.onGlass, true)
                .background {
                    ZStack {
                        Color.clear
                            .glassEffect(.regular.tint(p.glassTint)
                                            .interactive(interactive), in: shape)
                        // A thin wash of the card color keeps the preset recognisable
                        // and the text legible over busy or contrasting wallpaper.
                        shape.fill(p.glassWash).allowsHitTesting(false)
                    }
                    .environment(\.colorScheme, p.glassScheme)
                }
        } else {
            self.background(
                shape.fill(fill)
                    .shadow(color: .black.opacity(shadowOpacity), radius: shadow, y: shadowY)
            )
        }
    }

    /// Native glass buttons when the theme is on; the given fallback style otherwise.
    @ViewBuilder
    func glassButton(_ glass: Bool, prominent: Bool = false) -> some View {
        if glass, #available(macOS 26, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self
        }
    }

    /// Lets nearby glass shapes blend into each other (no-op without glass).
    @ViewBuilder
    func glassContainer(_ glass: Bool, spacing: CGFloat? = nil) -> some View {
        if glass, #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

/// "Liquid Glass theme" toggle, disabled with a note before macOS 26.
struct GlassThemeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("Liquid Glass theme", isOn: GlassSupport.isAvailable ? $isOn : .constant(false))
            .disabled(!GlassSupport.isAvailable)
        Text(GlassSupport.isAvailable
             ? "Widget, cards and buttons use translucent Liquid Glass tinted with your colors."
             : "Requires macOS 26 or later.")
            .font(.caption).foregroundStyle(.secondary)
    }
}
