import SwiftUI
import AppKit

/// Tracks which surfaces (main window, settings, widget) are actually visible on
/// screen, so clocks that nobody can see stop ticking and rendering.
@Observable
@MainActor
final class Visibility {
    static let shared = Visibility()
    private(set) var visible: Set<String> = []

    func isVisible(_ id: String) -> Bool { visible.contains(id) }

    fileprivate func set(_ id: String, _ isVisible: Bool) {
        if isVisible, !visible.contains(id) { visible.insert(id) }
        if !isVisible, visible.contains(id) { visible.remove(id) }
    }
}

/// Which surface a clock is drawn on. `nil` = always live (alarm alert, snapshots).
private struct ClockSurfaceKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var clockSurface: String? {
        get { self[ClockSurfaceKey.self] }
        set { self[ClockSurfaceKey.self] = newValue }
    }
}

extension View {
    /// Marks this window's content as surface `id` and reports when it is on screen.
    func trackVisibility(_ id: String) -> some View {
        environment(\.clockSurface, id)
            .background(VisibilityProbe(id: id))
    }
}

private struct VisibilityProbe: NSViewRepresentable {
    let id: String
    func makeNSView(context: Context) -> ProbeView { ProbeView(id: id) }
    func updateNSView(_ nsView: ProbeView, context: Context) {}
}

private final class ProbeView: NSView {
    let id: String
    private var observers: [NSObjectProtocol] = []

    init(id: String) {
        self.id = id
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else {
            report(false)
            return
        }
        let names: [Notification.Name] = [
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.willCloseNotification,
        ]
        for name in names {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] note in
                self?.refresh(closing: note.name == NSWindow.willCloseNotification)
            })
        }
        refresh(closing: false)
    }

    private func refresh(closing: Bool) {
        let onScreen = !closing && (window?.occlusionState.contains(.visible) ?? false) && !(window?.isMiniaturized ?? true)
        report(onScreen)
    }

    private func report(_ visible: Bool) {
        let id = id
        MainActor.assumeIsolated { Visibility.shared.set(id, visible) }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}
