import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set only by "Quit Tickdesk" in the menu bar icon (or logout/shutdown).
    static var allowTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            #if DEBUG
            if CommandLine.arguments.contains("--glass-snapshot") { GlassSnapshot.runIfRequested(); return }
            #endif
            Snapshot.runIfRequested()
            ClockSettings.shared.applyAppearance()
            DesktopWidgetController.shared.sync()
            _ = AlarmStore.shared
            DockPresence.shared.start()
            // `--background`: start with only the widget and menu bar icon.
            if CommandLine.arguments.contains("--background") {
                DispatchQueue.main.async { MainActor.assumeIsolated { DockPresence.shared.closeAppWindows() } }
            } else {
                // macOS may restore "no windows" from last session; a normal launch should show the app.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    MainActor.assumeIsolated {
                        let anyOpen = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) && $0.canBecomeMain }
                        if !anyOpen { AppActions.shared.open("main") }
                    }
                }
            }
        }
        // Never block a logout, restart or shutdown.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { _ in
            AppDelegate.allowTermination = true
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.allowTermination || Self.isSystemQuit() { return .terminateNow }
        // ⌘Q / Dock "Quit": close the app's windows but keep the widget and menu bar icon.
        MainActor.assumeIsolated { DockPresence.shared.closeAppWindows() }
        return .terminateCancel
    }

    /// True when macOS itself is quitting apps (logout, restart, shutdown).
    private static func isSystemQuit() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == kCoreEventClass, event.eventID == kAEQuitApplication,
              let reason = event.attributeDescriptor(forKeyword: kAEQuitReason)?.enumCodeValue
        else { return false }
        return [kAELogOut, kAEReallyLogOut, kAEShowRestartDialog, kAEShowShutdownDialog,
                kAERestart, kAEShutDown].contains(reason)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { MainActor.assumeIsolated { AppActions.shared.open("main") } }
        return true
    }
}

/// Shows the Dock icon only while a Tickdesk window is open; the widget and the
/// menu bar icon keep running without it.
@MainActor
final class DockPresence {
    static let shared = DockPresence()

    func start() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            MainActor.assumeIsolated {
                if let w = note.object as? NSWindow, Self.isAppWindow(w) { self.showInDock() }
            }
        }
        nc.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let closing = note.object as? NSWindow else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.updateAfterClosing(closing) }
            }
        }
    }

    private static func isAppWindow(_ w: NSWindow) -> Bool {
        !(w is NSPanel) && w.canBecomeMain
    }

    func showInDock() {
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
    }

    private func updateAfterClosing(_ closing: NSWindow) {
        let stillOpen = NSApp.windows.contains { $0 !== closing && $0.isVisible && Self.isAppWindow($0) }
        if !stillOpen { NSApp.setActivationPolicy(.accessory) }
    }

    func closeAppWindows() {
        for w in NSApp.windows where Self.isAppWindow(w) && w.isVisible { w.close() }
        NSApp.setActivationPolicy(.accessory)
        DesktopWidgetController.shared.sync()
    }
}

@main
struct TickdeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let settings = ClockSettings.shared
    private let alarms = AlarmStore.shared

    var body: some Scene {
        Window("Tickdesk", id: "main") {
            MainView()
                .environment(settings)
                .environment(alarms)
        }
        .defaultSize(width: 820, height: 580)
        .commands { AppCommands() }

        Window("Tickdesk Settings", id: "settings") {
            SettingsView()
                .environment(settings)
                .environment(alarms)
        }
        .windowResizability(.contentSize)

        Window("Alarms", id: "alarms") {
            AlarmsView()
                .environment(settings)
                .environment(alarms)
        }
        .defaultSize(width: 600, height: 420)

        MenuBarExtra {
            MenuContent()
                .environment(settings)
                .environment(alarms)
        } label: {
            MenuBarLabel()
        }
    }
}

private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Image(systemName: "clock.fill")
            .onAppear { AppActions.shared.openWindow = openWindow }
    }
}

private struct MenuContent: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var settings = settings
        Button("Open Tickdesk") { open("main") }
        Toggle("Show Desktop Widget", isOn: $settings.config.widgetVisible)
        Toggle("Show Seconds", isOn: $settings.config.showSeconds)
        Picker("Appearance", selection: $settings.config.appearance) {
            ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
        }
        Picker("Clock Style", selection: $settings.config.face) {
            ForEach(FaceStyle.allCases) { Text($0.title).tag($0) }
        }
        Divider()
        Button("Alarms…") { open("alarms") }
        Menu("Wallpaper") {
            Button("Match Clock Theme") { SystemActions.themeWallpaper() }
            Button("Choose Image…") { SystemActions.chooseWallpaper() }
        }
        Menu("Sleep") {
            Button("Turn Off Display") { SystemActions.sleepDisplay() }
            Button("Start Screen Saver") { SystemActions.startScreenSaver() }
            Button("Sleep Mac") { SystemActions.sleepMac() }
        }
        Divider()
        Button("Settings…") { open("settings") }.keyboardShortcut(",")
        Button("Quit Tickdesk") {
            AppDelegate.allowTermination = true
            NSApp.terminate(nil)
        }
    }

    private func open(_ id: String) {
        DockPresence.shared.showInDock()
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }
}

private struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appSettings) { OpenWindowButton(title: "Settings…", id: "settings", key: ",") }
        CommandGroup(replacing: .appTermination) {
            Button("Close Tickdesk (Widget Stays)") { DockPresence.shared.closeAppWindows() }
                .keyboardShortcut("q")
        }
        CommandGroup(after: .windowArrangement) {
            OpenWindowButton(title: "Alarms", id: "alarms", key: "a", modifiers: [.command, .shift])
            Button("Toggle Desktop Widget") { DesktopWidgetController.shared.toggle() }
                .keyboardShortcut("w", modifiers: [.command, .shift])
        }
    }
}

private struct OpenWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    let title: String
    let id: String
    let key: KeyEquivalent
    var modifiers: EventModifiers = .command
    var body: some View {
        Button(title) { openWindow(id: id) }.keyboardShortcut(key, modifiers: modifiers)
    }
}
