import SwiftUI
import AppKit

struct Alarm: Codable, Identifiable, Equatable {
    var id = UUID()
    var hour = 7
    var minute = 0
    var label = "Alarm"
    var enabled = true
    /// Calendar weekdays (1 = Sunday … 7 = Saturday). Empty = one-shot.
    var days: Set<Int> = []
    var sound = "Glass"

    var time: Date {
        get { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date() }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            hour = c.hour ?? 0
            minute = c.minute ?? 0
        }
    }

    var repeatSummary: String {
        if days.isEmpty { return "Once" }
        if days.count == 7 { return "Every day" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days == [1, 7] { return "Weekends" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return days.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
    }
}

@Observable
@MainActor
final class AlarmStore {
    static let shared = AlarmStore()
    private static let key = "Tickdesk.alarms.v1"

    static let sounds: [String] = {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? []
        let names = files.map { ($0 as NSString).deletingPathExtension }.sorted()
        return names.isEmpty ? ["Glass"] : names
    }()

    var alarms: [Alarm] = [] {
        didSet { save() }
    }
    private(set) var ringing: Alarm?

    private var snoozes: [(due: Date, alarm: Alarm)] = []
    private var timer: Timer?
    private var sound: NSSound?
    private var lastFiredKey = ""

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
        }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func save() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func add() {
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
        var a = Alarm()
        a.time = next
        alarms.append(a)
    }

    func remove(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
    }

    private func tick() {
        let now = Date()
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        let key = "\(c.year!)-\(c.month!)-\(c.day!) \(c.hour!):\(c.minute!)"

        if key != lastFiredKey, ringing == nil {
            if let a = alarms.first(where: {
                $0.enabled && $0.hour == c.hour && $0.minute == c.minute &&
                ($0.days.isEmpty || $0.days.contains(c.weekday!))
            }) {
                lastFiredKey = key
                if a.days.isEmpty, let i = alarms.firstIndex(where: { $0.id == a.id }) {
                    alarms[i].enabled = false
                }
                fire(a)
                return
            }
        }
        if ringing == nil, let i = snoozes.firstIndex(where: { $0.due <= now }) {
            fire(snoozes.remove(at: i).alarm)
        }
    }

    func fire(_ alarm: Alarm) {
        ringing = alarm
        sound?.stop()
        sound = NSSound(named: NSSound.Name(alarm.sound))
        sound?.loops = true
        sound?.play()
        AlarmRingController.shared.show()
    }

    func test(_ alarm: Alarm) { fire(alarm) }

    func stop() {
        sound?.stop()
        sound = nil
        ringing = nil
        AlarmRingController.shared.close()
    }

    func snooze(minutes: Int = 5) {
        if let a = ringing {
            snoozes.append((Date().addingTimeInterval(TimeInterval(minutes * 60)), a))
        }
        stop()
    }
}

@MainActor
final class AlarmRingController {
    static let shared = AlarmRingController()
    private var panel: NSPanel?

    func show() {
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
                            styleMask: [.titled, .fullSizeContentView],
                            backing: .buffered, defer: false)
            p.titlebarAppearsTransparent = true
            p.titleVisibility = .hidden
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isMovableByWindowBackground = true
            let host = NSHostingView(rootView: AlarmRingView()
                .environment(ClockSettings.shared)
                .environment(AlarmStore.shared))
            host.sizingOptions = [.intrinsicContentSize]
            p.contentView = host
            p.center()
            panel = p
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct AlarmRingView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(ClockSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = settings.palette(for: scheme)
        VStack(spacing: 18) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 34))
                .foregroundStyle(p.accent)
                .symbolEffect(.pulse)
            ClockFace(style: .minimal, size: 40)
            Text(store.ringing?.label ?? "Alarm")
                .font(settings.font(18, weight: .semibold))
                .foregroundStyle(p.digit)
            HStack(spacing: 12) {
                Button("Snooze 5 min") { store.snooze() }
                    .controlSize(.large)
                Button("Stop") { store.stop() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .tint(p.accent)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(minWidth: 340)
        .background(p.background)
    }
}

// MARK: - Alarm editor window

struct AlarmsView: View {
    @Environment(AlarmStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            if store.alarms.isEmpty {
                ContentUnavailableView("No Alarms", systemImage: "alarm",
                                       description: Text("Add an alarm and Tickdesk will ring at that time."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach($store.alarms) { $alarm in
                        AlarmRow(alarm: $alarm)
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            HStack {
                Button { store.add() } label: { Label("Add Alarm", systemImage: "plus") }
                Spacer()
                Text("Alarms ring while Tickdesk is running.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}

private struct AlarmRow: View {
    @Binding var alarm: Alarm
    @Environment(AlarmStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                DatePicker("", selection: $alarm.time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .font(.title3)
                TextField("Label", text: $alarm.label)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $alarm.sound) {
                    ForEach(AlarmStore.sounds, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 110)
                Button { store.test(alarm) } label: { Image(systemName: "speaker.wave.2") }
                    .help("Test this alarm")
                Toggle("", isOn: $alarm.enabled).toggleStyle(.switch).labelsHidden()
                Button(role: .destructive) { store.remove(alarm) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    let on = alarm.days.contains(day)
                    Button(Calendar.current.veryShortWeekdaySymbols[day - 1]) {
                        if on { alarm.days.remove(day) } else { alarm.days.insert(day) }
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? .accentColor : nil)
                    .controlSize(.small)
                }
                Text(alarm.repeatSummary).font(.caption).foregroundStyle(.secondary).padding(.leading, 6)
            }
        }
        .padding(.vertical, 6)
        .opacity(alarm.enabled ? 1 : 0.6)
    }
}
