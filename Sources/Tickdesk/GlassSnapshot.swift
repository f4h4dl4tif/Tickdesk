#if DEBUG
import SwiftUI
import AppKit
import Darwin

/// Developer aid: `Tickdesk --glass-snapshot <dir>` opens the widget, main window and
/// Settings with Liquid Glass off and on, in light and dark, captures each real on-screen
/// window (ImageRenderer can't draw glass), writes PNGs and quits. Saved settings are restored.
@MainActor
enum GlassSnapshot {
    private typealias CapFn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    private static var jobs: [(@escaping () -> Void) -> Void] = []
    private static var dir = URL(fileURLWithPath: ".")
    private static var keepAlive: [NSWindow] = []

    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--glass-snapshot"), i + 1 < args.count else { return }
        dir = URL(fileURLWithPath: args[i + 1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let defaults = UserDefaults.standard
        let savedData = defaults.data(forKey: "Tickdesk.config.v1")
        let savedTopLeft = defaults.string(forKey: "Tickdesk.widget.origin")
        let settings = ClockSettings.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let wallpaper = desktopPicture()
        let bright = Image(nsImage: brightBackdrop())
        var base = settings.config
        base.widgetVisible = false
        base.face = .flip
        base.presetID = "classic"
        base.showSeconds = true
        base.showDate = true

        for glass in [false, true] {
            for scheme in [ColorScheme.light, .dark] {
                let tag = "\(glass ? "glass" : "plain")-\(scheme == .dark ? "dark" : "light")"
                var c = base
                c.glassTheme = glass
                c.appearance = scheme == .dark ? .dark : .light

                // Desktop widget as shipped (Flip, no background panel) over the real desktop picture.
                add("widget-\(tag)", scheme) {
                    clock(c, style: .flip, background: false).padding(40)
                        .background(wallpaper.resizable().aspectRatio(contentMode: .fill))
                }
                // Every face without and with the background panel over a colorful backdrop.
                add("faces-\(tag)", scheme) {
                    VStack(alignment: .leading, spacing: 28) {
                        HStack(alignment: .center, spacing: 32) {
                            ForEach(FaceStyle.allCases) { s in clock(c, style: s, background: false, size: 34) }
                        }
                        HStack(alignment: .center, spacing: 32) {
                            ForEach(FaceStyle.allCases) { s in clock(c, style: s, background: true, size: 34) }
                        }
                    }
                    .padding(36)
                    .background(bright.resizable().aspectRatio(contentMode: .fill))
                }
                // Color presets.
                add("presets-\(tag)", scheme) {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach([["ink", "midnight", "sunset"], ["lcd", "wood", "neon"]], id: \.self) { row in
                            HStack(spacing: 32) {
                                ForEach(row, id: \.self) { id in
                                    var pc = c
                                    pc.presetID = id
                                    return clock(pc, style: .flip, background: false, size: 34)
                                }
                            }
                        }
                    }
                    .padding(32)
                    .background(wallpaper.resizable().aspectRatio(contentMode: .fill))
                }
                // Main window and Settings use the live config.
                jobs.append { done in settings.config = c; done() }
                addWindow("main-\(tag)", scheme, size: NSSize(width: 900, height: 600), titled: true) {
                    AnyView(MainView().environment(settings))
                }
                addWindow("settings-\(tag)", scheme, size: nil, titled: true) {
                    AnyView(SettingsView().environment(settings))
                }
            }
        }
        jobs.append { _ in
            if let savedData { defaults.set(savedData, forKey: "Tickdesk.config.v1") } else { defaults.removeObject(forKey: "Tickdesk.config.v1") }
            if let savedTopLeft { defaults.set(savedTopLeft, forKey: "Tickdesk.widget.origin") } else { defaults.removeObject(forKey: "Tickdesk.widget.origin") }
            defaults.synchronize()
            exit(0)
        }
        // Hide the window SwiftUI opens at launch, then start.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            MainActor.assumeIsolated {
                for w in NSApp.windows where !keepAlive.contains(w) { w.orderOut(nil) }
                next()
            }
        }
    }

    private static func clock(_ c: ClockConfig, style: FaceStyle, background: Bool, size: CGFloat = 44) -> some View {
        ClockFace(style: style, size: size, showsBackground: background, animated: false)
            .fixedSize()
            .environment(ClockSettings.shared)
            .environment(\.previewConfig, c)
    }

    private static func add<V: View>(_ name: String, _ scheme: ColorScheme, @ViewBuilder _ content: @escaping () -> V) {
        addWindow(name, scheme, size: nil, titled: false) {
            AnyView(content().environment(\.colorScheme, scheme))
        }
    }

    private static func addWindow(_ name: String, _ scheme: ColorScheme, size: NSSize?, titled: Bool,
                                  _ content: @escaping () -> AnyView) {
        jobs.append { done in
            let host = NSHostingController(rootView: content())
            host.sceneBridgingOptions = [.toolbars, .title]
            let style: NSWindow.StyleMask = titled ? [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView] : [.borderless]
            let win = NSWindow(contentViewController: host)
            win.styleMask = style
            win.title = titled ? "Tickdesk" : ""
            win.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            win.isReleasedWhenClosed = false
            let s = size ?? host.view.fittingSize
            win.setContentSize(s)
            win.setFrameOrigin(NSPoint(x: 80, y: 80))
            win.level = .floating
            win.orderFrontRegardless()
            win.makeKey()
            keepAlive.append(win)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                MainActor.assumeIsolated {
                    capture(win, name)
                    win.orderOut(nil)
                    done()
                }
            }
        }
    }

    private static func next() {
        guard !jobs.isEmpty else { return }
        let job = jobs.removeFirst()
        job { DispatchQueue.main.async { MainActor.assumeIsolated { next() } } }
    }

    private static func capture(_ win: NSWindow, _ name: String) {
        guard let sym = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage") else { return }
        let f = unsafeBitCast(sym, to: CapFn.self)
        guard let img = f(.null, 8, UInt32(win.windowNumber), 1 | 8)?.takeRetainedValue(),
              let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else {
            print("capture failed:", name)
            return
        }
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
        print("wrote", name, win.frame, win.isVisible, win.occlusionState.contains(.visible), img.width, img.height, win.windowNumber)
    }

    private static func desktopPicture() -> Image {
        if let screen = NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen),
           let img = NSImage(contentsOf: url) {
            return Image(nsImage: img)
        }
        return Image(nsImage: brightBackdrop())
    }

    /// A busy, colorful stand-in wallpaper so glass refraction is visible.
    private static func brightBackdrop() -> NSImage {
        NSImage(size: NSSize(width: 1600, height: 1000), flipped: false) { r in
            NSGradient(colors: [NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.35, alpha: 1),
                                NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.55, alpha: 1),
                                NSColor(calibratedRed: 0.35, green: 0.45, blue: 0.95, alpha: 1)])?
                .draw(in: r, angle: -30)
            let blobs: [(CGFloat, CGFloat, CGFloat, NSColor)] = [
                (0.15, 0.7, 260, .systemYellow), (0.5, 0.3, 320, .systemTeal),
                (0.8, 0.75, 280, .white), (0.35, 0.15, 200, .systemPurple), (0.65, 0.55, 160, .black),
            ]
            for (x, y, d, c) in blobs {
                c.withAlphaComponent(0.75).setFill()
                NSBezierPath(ovalIn: NSRect(x: r.width * x - d / 2, y: r.height * y - d / 2, width: d, height: d)).fill()
            }
            return true
        }
    }
}
#endif
