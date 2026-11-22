import SwiftUI
import AppKit

/// Developer aid: `Tickdesk --snapshot <dir>` renders every face to PNG and exits.
@MainActor
enum Snapshot {
    static func runIfRequested() {
        let args = CommandLine.arguments
        if args.contains("--selftest") { selfTest() }
        if let j = args.firstIndex(of: "--frames"), j + 1 < args.count { recordFrames(to: args[j + 1]); return }
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = ClockSettings.shared
        let saved = settings.config
        let combos: [(String, FaceStyle, String, FontStyle, ColorScheme)] = [
            ("flip-light", .flip, "classic", .rounded, .light),
            ("flip-dark", .flip, "classic", .rounded, .dark),
            ("minimal-sunset-dark", .minimal, "sunset", .avenir, .dark),
            ("segment-lcd-light", .segment, "lcd", .din, .light),
            ("analog-midnight-dark", .analog, "midnight", .futura, .dark),
            ("flip-neon-12h", .flip, "neon", .didot, .dark),
            ("dots-classic-light-12h", .dotMatrix, "classic", .mono, .light),
            ("dots-neon-dark", .dotMatrix, "neon", .rounded, .dark),
        ]
        for (name, face, preset, font, scheme) in combos {
            settings.config.face = face
            settings.config.presetID = preset
            settings.config.font = font
            settings.config.use24h = !name.contains("12h")
            settings.config.dateStyle = face == .dotMatrix ? .compact : saved.dateStyle
            let view = ClockFace(size: 60, showsBackground: true, animated: false)
                .padding(20)
                .environment(settings)
                .environment(\.colorScheme, scheme)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("\(name).png"))
            }
        }
        settings.config = saved
        exit(0)
    }

    /// Checks that Settings edits stay a draft until saved.
    private static func selfTest() {
        let s = ClockSettings.shared
        let saved = s.config
        func check(_ ok: Bool, _ msg: String) { print(ok ? "PASS" : "FAIL", msg) }
        s.draft.font = s.config.font == .futura ? .didot : .futura
        check(s.hasUnsavedChanges, "editing the draft marks unsaved changes")
        check(s.config.font == saved.font, "the live clock is unchanged before Save")
        s.revertDraft()
        check(!s.hasUnsavedChanges && s.draft == s.config, "Revert discards the draft")
        s.draft.showSeconds.toggle()
        s.saveDraft()
        check(s.config.showSeconds != saved.showSeconds && !s.hasUnsavedChanges, "Save applies the draft")
        s.config.blinkColon.toggle()
        check(s.draft.blinkColon == s.config.blinkColon, "quick toggles keep a clean draft in sync")
        s.draft.presetID = "neon"
        s.config.use24h.toggle()
        check(s.draft.presetID == "neon", "quick toggles don't wipe unsaved edits")
        s.config = saved
        s.draft = saved
        exit(0)
    }

    /// Records the Flip face for ~1.3 s at 25 fps to check the digit roll animates.
    private static func recordFrames(to path: String) {
        let dir = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let s = ClockSettings.shared
        s.config.face = .flip
        s.config.widgetVisible = false
        let host = NSHostingView(rootView: ClockFace(style: .flip, size: 60, showsBackground: true)
            .padding(20).environment(s))
        let win = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 640, height: 260),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.level = .floating
        win.contentView = host
        win.orderFrontRegardless()
        // Start just before the next second boundary.
        let now = Date().timeIntervalSince1970
        let wait = (ceil(now) - now) + 0.85
        var n = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { t in
                MainActor.assumeIsolated {
                    guard let layer = host.layer else { return }
                    let size = host.bounds.size
                    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
                    ctx.translateBy(x: 0, y: size.height)
                    ctx.scaleBy(x: 1, y: -1)
                    (layer.presentation() ?? layer).render(in: ctx)
                    try? rep.representation(using: .png, properties: [:])?
                        .write(to: dir.appendingPathComponent(String(format: "f%02d.png", n)))
                    n += 1
                    if n >= 32 { t.invalidate(); exit(0) }
                }
            }
        }
    }
}
