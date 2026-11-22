import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Bridges AppKit code (widget menu, alarms) to SwiftUI window opening.
@MainActor
final class AppActions {
    static let shared = AppActions()
    var openWindow: OpenWindowAction?

    func open(_ id: String) {
        DockPresence.shared.showInDock()
        NSApp.activate(ignoringOtherApps: true)
        openWindow?(id: id)
    }
}

@MainActor
enum SystemActions {
    static func sleepDisplay() { run("/usr/bin/pmset", ["displaysleepnow"]) }
    static func sleepMac() { run("/usr/bin/pmset", ["sleepnow"]) }
    static func startScreenSaver() { run("/usr/bin/open", ["-a", "ScreenSaverEngine"]) }

    private static func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run()
    }

    static func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose an image to use as your desktop wallpaper"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setWallpaper(url)
    }

    /// One click: paints the desktop with a gradient from the current clock theme.
    static func themeWallpaper() {
        let settings = ClockSettings.shared
        let palette = settings.palette(for: settings.effectiveScheme)
        let screen = NSScreen.main ?? NSScreen.screens.first
        let scale = screen?.backingScaleFactor ?? 2
        let size = NSSize(width: (screen?.frame.width ?? 1728) * scale, height: (screen?.frame.height ?? 1117) * scale)

        let image = NSImage(size: size, flipped: false) { rect in
            let top = NSColor(palette.background)
            let bottom = NSColor(palette.card).blended(withFraction: 0.5, of: top) ?? top
            NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)
            return true
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tickdesk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Remove older generated wallpapers; a fresh filename forces macOS to refresh.
        for old in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        where old.lastPathComponent.hasPrefix("wallpaper-") {
            try? FileManager.default.removeItem(at: old)
        }
        let url = dir.appendingPathComponent("wallpaper-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try png.write(to: url)
            setWallpaper(url)
        } catch {
            NSLog("Tickdesk: wallpaper write failed: \(error)")
        }
    }

    static func setWallpaper(_ url: URL) {
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
    }
}
