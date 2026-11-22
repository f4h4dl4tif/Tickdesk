import SwiftUI
import AppKit

private final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The borderless clock that lives on the desktop.
@MainActor
final class DesktopWidgetController {
    static let shared = DesktopWidgetController()
    private static let originKey = "Tickdesk.widget.origin"

    private(set) var panel: NSPanel?
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    func sync() {
        let c = ClockSettings.shared.config
        guard c.widgetVisible else {
            panel?.orderOut(nil)
            return
        }
        if panel == nil { createPanel() }
        guard let panel else { return }
        panel.level = c.widgetLevel.windowLevel
        panel.alphaValue = c.widgetOpacity
        panel.orderFrontRegardless()
    }

    func toggle() {
        ClockSettings.shared.config.widgetVisible.toggle()
    }

    private func createPanel() {
        let panel = WidgetPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: WidgetRootView().environment(ClockSettings.shared))
        host.sizingOptions = [.intrinsicContentSize, .minSize, .maxSize]
        panel.contentView = host

        if let saved = UserDefaults.standard.string(forKey: Self.originKey) {
            panel.setFrameOrigin(NSPointFromString(saved))
        } else if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: vf.maxX - 360, y: vf.maxY - 200))
        }
        self.panel = panel
    }

    // Manual dragging so it works at desktop level and respects the lock.
    func dragChanged() {
        guard let panel, !ClockSettings.shared.config.widgetLocked else { return }
        let mouse = NSEvent.mouseLocation
        if dragStart == nil { dragStart = (mouse, panel.frame.origin) }
        guard let start = dragStart else { return }
        panel.setFrameOrigin(NSPoint(x: start.origin.x + mouse.x - start.mouse.x,
                                     y: start.origin.y + mouse.y - start.mouse.y))
    }

    func dragEnded() {
        dragStart = nil
        if let panel {
            UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originKey)
        }
    }
}

private struct WidgetRootView: View {
    @Environment(ClockSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        ClockFace(style: settings.config.widgetFace,
                  size: 44 * settings.config.widgetScale,
                  showsBackground: settings.config.widgetBackground)
            .padding(14) // room for shadows
            .trackVisibility("widget")
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { _ in DesktopWidgetController.shared.dragChanged() }
                    .onEnded { _ in DesktopWidgetController.shared.dragEnded() }
            )
            .contextMenu {
                Picker("Widget Style", selection: $settings.config.widgetFace) {
                    Text("Same as Main Clock").tag(FaceStyle?.none)
                    Divider()
                    ForEach(FaceStyle.allCases) { Text($0.title).tag(FaceStyle?.some($0)) }
                }
                Picker("Position", selection: $settings.config.widgetLevel) {
                    ForEach(WidgetLevel.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show Seconds", isOn: $settings.config.showSeconds)
                Toggle("Show Date", isOn: $settings.config.showDate)
                Toggle("Show Background", isOn: $settings.config.widgetBackground)
                Toggle("Lock Position", isOn: $settings.config.widgetLocked)
                Divider()
                Button("Open Tickdesk") { AppActions.shared.open("main") }
                Button("Settings…") { AppActions.shared.open("settings") }
                Button("Hide Widget") { settings.config.widgetVisible = false }
            }
    }
}
