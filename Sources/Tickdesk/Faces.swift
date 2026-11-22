import SwiftUI

struct TimeParts {
    let h: Int, m: Int, s: Int
    let hour: String, minute: String, second: String
    let ampm: String?
    let date: String
    let colonOn: Bool

    init(_ date: Date, _ c: ClockConfig) {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        h = comps.hour ?? 0
        m = comps.minute ?? 0
        s = comps.second ?? 0
        var hh = h
        if c.use24h {
            ampm = nil
        } else {
            ampm = h < 12 ? "AM" : "PM"
            hh = h % 12
            if hh == 0 { hh = 12 }
        }
        hour = String(format: "%02d", hh)
        minute = String(format: "%02d", m)
        second = String(format: "%02d", s)
        colonOn = !c.blinkColon || s % 2 == 0
        self.date = c.dateStyle.format(date)
    }
}

/// Renders the current time in the chosen face style, palette and font.
struct ClockFace: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.previewConfig) private var preview
    private var cfg: ClockConfig { preview ?? settings.config }
    @Environment(\.colorScheme) private var scheme
    @Environment(\.clockSurface) private var surface

    var style: FaceStyle? = nil
    /// Nominal digit height in points; every face scales from it.
    var size: CGFloat
    var showsBackground = false
    var animated = true

    /// Seconds only need a redraw every second when something on the face changes that often.
    private var tickInterval: TimeInterval {
        let face = style ?? cfg.face
        let blinks = cfg.blinkColon && face != .flip && face != .analog
        return cfg.showSeconds || blinks ? 1 : 60
    }

    var body: some View {
        if let surface, !Visibility.shared.isVisible(surface) {
            // Nobody can see this window: draw once and stop ticking.
            content(Date())
        } else {
            let interval = tickInterval
            let start = Date(timeIntervalSinceReferenceDate:
                floor(Date().timeIntervalSinceReferenceDate / interval) * interval)
            TimelineView(.periodic(from: start, by: interval)) { ctx in
                content(ctx.date)
            }
        }
    }

    private func content(_ date: Date) -> some View {
        let t = TimeParts(date, cfg)
        let p = cfg.palette(for: scheme)
        return face(t, p)
            .padding(showsBackground ? size * 0.35 : 0)
            .background {
                if showsBackground {
                    RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                        .fill(p.background)
                        .shadow(color: .black.opacity(0.18), radius: size * 0.12, y: size * 0.04)
                }
            }
    }

    @ViewBuilder
    private func face(_ t: TimeParts, _ p: Palette) -> some View {
        switch style ?? cfg.face {
        case .flip: FlipFace(t: t, p: p, size: size, animated: animated)
        case .minimal: MinimalFace(t: t, p: p, size: size, animated: animated)
        case .segment: SegmentFace(t: t, p: p, size: size)
        case .dotMatrix: DotMatrixFace(t: t, p: p, size: size)
        case .analog: AnalogFace(t: t, p: p, size: size)
        }
    }
}

// MARK: - Flip

private struct FlipCard: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.previewConfig) private var preview
    private var cfg: ClockConfig { preview ?? settings.config }
    let text: String
    let p: Palette
    let size: CGFloat
    var corner: String? = nil
    var animated: Bool

    var body: some View {
        RollingText(text: text, fontSize: size)
            .font(cfg.typeface(size))
            .monospacedDigit()
            .foregroundStyle(p.digit)
            .animation(animated ? .spring(duration: 0.5, bounce: 0.25) : nil, value: text)
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: size * 1.3)
            .padding(.horizontal, size * 0.12)
            .padding(.vertical, size * 0.1)
            .background(
                RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                    .fill(p.card)
                    .shadow(color: .black.opacity(0.16), radius: size * 0.06, y: size * 0.03)
            )
            .overlay {
                // The hinge line across the middle of a flip card.
                Rectangle()
                    .fill(p.background.opacity(0.55))
                    .frame(height: max(1, size * 0.022))
            }
            .overlay(alignment: .topLeading) {
                if let corner {
                    Text(corner)
                        .font(cfg.typeface(size * 0.17, weight: .semibold))
                        .foregroundStyle(p.digit.opacity(0.7))
                        .padding(size * 0.09)
                }
            }
    }
}

private struct FlipFace: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.previewConfig) private var preview
    private var cfg: ClockConfig { preview ?? settings.config }
    let t: TimeParts, p: Palette, size: CGFloat, animated: Bool

    var body: some View {
        VStack(spacing: size * 0.22) {
            HStack(spacing: size * 0.14) {
                FlipCard(text: t.hour, p: p, size: size, corner: t.ampm, animated: animated)
                FlipCard(text: t.minute, p: p, size: size, animated: animated)
                if cfg.showSeconds {
                    FlipCard(text: t.second, p: p, size: size, animated: animated)
                }
            }
            DateLine(t: t, p: p, size: size)
        }
    }
}

/// Digits that roll into place when they change: the new digit rises in while
/// the old one rises out, with a scale and fade. It only animates transforms and
/// opacity, so unlike `.numericText()` it never blurs on the CPU each frame.
private struct RollingText: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        let travel = fontSize * 0.42
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                ZStack {
                    Text(String(ch))
                        .id(ch)
                        .transition(.asymmetric(
                            insertion: .offset(y: travel).combined(with: .scale(scale: 0.6, anchor: .bottom)).combined(with: .opacity),
                            removal: .offset(y: -travel).combined(with: .scale(scale: 0.6, anchor: .top)).combined(with: .opacity)))
                }
            }
        }
    }
}

// MARK: - Minimal

private struct MinimalFace: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.previewConfig) private var preview
    private var cfg: ClockConfig { preview ?? settings.config }
    let t: TimeParts, p: Palette, size: CGFloat, animated: Bool

    var body: some View {
        VStack(spacing: size * 0.08) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                RollingText(text: t.hour, fontSize: size * 1.25)
                Text(":").opacity(t.colonOn ? 1 : 0.2).padding(.horizontal, size * 0.02)
                RollingText(text: t.minute, fontSize: size * 1.25)
                if cfg.showSeconds {
                    RollingText(text: t.second, fontSize: size * 0.42)
                        .font(cfg.typeface(size * 0.42))
                        .foregroundStyle(p.accent)
                        .padding(.leading, size * 0.1)
                }
                if let ampm = t.ampm {
                    Text(ampm)
                        .font(cfg.typeface(size * 0.24, weight: .semibold))
                        .foregroundStyle(p.digit.opacity(0.7))
                        .padding(.leading, size * 0.08)
                }
            }
            .font(cfg.typeface(size * 1.25))
            .monospacedDigit()
            .foregroundStyle(p.digit)
            .animation(animated ? .snappy : nil, value: t.second)
            .lineLimit(1)
            .fixedSize()

            DateLine(t: t, p: p, size: size)
        }
    }
}

// MARK: - Seven segment

/// The seven segments (a–g) of one digit, as a vector shape. `lit` picks which to include.
private struct SegmentShape: Shape {
    let mask: [Bool]
    let lit: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let t = w * 0.18, gap = t * 0.12
        func hSeg(_ y: CGFloat) -> Path {
            let x0 = t / 2 + gap, x1 = w - t / 2 - gap
            var p = Path()
            p.move(to: CGPoint(x: x0, y: y))
            p.addLine(to: CGPoint(x: x0 + t / 2, y: y - t / 2))
            p.addLine(to: CGPoint(x: x1 - t / 2, y: y - t / 2))
            p.addLine(to: CGPoint(x: x1, y: y))
            p.addLine(to: CGPoint(x: x1 - t / 2, y: y + t / 2))
            p.addLine(to: CGPoint(x: x0 + t / 2, y: y + t / 2))
            p.closeSubpath()
            return p
        }
        func vSeg(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: x, y: y0))
            p.addLine(to: CGPoint(x: x + t / 2, y: y0 + t / 2))
            p.addLine(to: CGPoint(x: x + t / 2, y: y1 - t / 2))
            p.addLine(to: CGPoint(x: x, y: y1))
            p.addLine(to: CGPoint(x: x - t / 2, y: y1 - t / 2))
            p.addLine(to: CGPoint(x: x - t / 2, y: y0 + t / 2))
            p.closeSubpath()
            return p
        }
        let top = t / 2, mid = h / 2, bot = h - t / 2
        let left = t / 2, right = w - t / 2
        let segs: [Path] = [
            hSeg(top),
            vSeg(right, top + gap, mid - gap),
            vSeg(right, mid + gap, bot - gap),
            hSeg(bot),
            vSeg(left, mid + gap, bot - gap),
            vSeg(left, top + gap, mid - gap),
            hSeg(mid),
        ]
        var out = Path()
        for (i, seg) in segs.enumerated() where mask[i] == lit { out.addPath(seg) }
        return out.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

private struct SegmentDigit: View {
    let digit: Int?
    let on: Color
    let off: Color
    let height: CGFloat

    // Segments a b c d e f g
    private static let map: [[Bool]] = [
        [true, true, true, true, true, true, false],    // 0
        [false, true, true, false, false, false, false], // 1
        [true, true, false, true, true, false, true],   // 2
        [true, true, true, true, false, false, true],   // 3
        [false, true, true, false, false, true, true],  // 4
        [true, false, true, true, false, true, true],   // 5
        [true, false, true, true, true, true, true],    // 6
        [true, true, true, false, false, false, false], // 7
        [true, true, true, true, true, true, true],     // 8
        [true, true, true, true, false, true, true],    // 9
    ]

    var body: some View {
        let mask = digit.map { Self.map[$0] } ?? Array(repeating: false, count: 7)
        ZStack {
            SegmentShape(mask: mask, lit: false).fill(off)
            SegmentShape(mask: mask, lit: true).fill(on)
        }
        .frame(width: height * 0.56, height: height)
    }
}

private struct SegmentFace: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.previewConfig) private var preview
    private var cfg: ClockConfig { preview ?? settings.config }
    let t: TimeParts, p: Palette, size: CGFloat

    private func digits(_ s: String, height: CGFloat) -> some View {
        HStack(spacing: height * 0.14) {
            ForEach(Array(s.enumerated()), id: \.offset) { _, ch in
                SegmentDigit(digit: Int(String(ch)), on: p.digit, off: p.digit.opacity(0.08), height: height)
            }
        }
    }

    var body: some View {
        let hgt = size * 1.1
        VStack(alignment: .trailing, spacing: size * 0.12) {
            HStack(alignment: .bottom, spacing: hgt * 0.16) {
                if let ampm = t.ampm {
                    Text(ampm)
                        .font(cfg.typeface(size * 0.2, weight: .bold))
                        .foregroundStyle(p.digit)
                        .padding(.bottom, hgt * 0.7)
                }
                digits(t.hour, height: hgt)
                VStack(spacing: hgt * 0.28) {
                    Rectangle().frame(width: hgt * 0.1, height: hgt * 0.1)
                    Rectangle().frame(width: hgt * 0.1, height: hgt * 0.1)
                }
                .foregroundStyle(p.digit.opacity(t.colonOn ? 1 : 0.1))
                .padding(.bottom, hgt * 0.22)
                digits(t.minute, height: hgt)
                if cfg.showSeconds {
                    digits(t.second, height: hgt * 0.5)
                }
            }
            .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.08, d: 1, tx: hgt * 0.08, ty: 0))

            if cfg.showDate {
                Text(t.date.uppercased())
                    .font(.system(size: size * 0.18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(p.digit.opacity(0.8))
            }
        }
        .padding(.horizontal, size * 0.3)
        .padding(.vertical, size * 0.24)
        .background(
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(p.card)
                .shadow(color: .black.opacity(0.16), radius: size * 0.06, y: size * 0.03)
        )
    }
}

// MARK: - Dot matrix

/// 5×7 dot glyphs. Each row is 5 columns, "#" = lit.
private enum DotFont {
    static let glyphs: [Character: [String]] = [
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        ":": [".", ".", "#", ".", "#", ".", "."],
    ]
}

/// All lit dots of a string as one vector shape. `colons` picks colon dots or the rest.
private struct DotShape: Shape {
    let text: String
    let colons: Bool

    static func columns(_ text: String) -> Int {
        let glyphs = text.map { DotFont.glyphs[$0] ?? DotFont.glyphs["0"]! }
        return glyphs.reduce(0) { $0 + $1[0].count } + max(0, glyphs.count - 1)
    }

    func path(in rect: CGRect) -> Path {
        let pitch = rect.height / 7
        let dot = pitch * 0.8
        var out = Path()
        var x0 = 0
        for ch in text {
            let glyph = DotFont.glyphs[ch] ?? DotFont.glyphs["0"]!
            if (ch == ":") == colons {
                for (row, line) in glyph.enumerated() {
                    for (col, bit) in line.enumerated() where bit == "#" {
                        out.addEllipse(in: CGRect(x: rect.minX + CGFloat(x0 + col) * pitch + (pitch - dot) / 2,
                                                  y: rect.minY + CGFloat(row) * pitch + (pitch - dot) / 2,
                                                  width: dot, height: dot))
                    }
                }
            }
            x0 += glyph[0].count + 1
        }
        return out
    }
}

private struct DotText: View {
    let text: String
    let color: Color
    /// Distance between dot centres.
    let pitch: CGFloat
    var colonOn = true

    var body: some View {
        ZStack {
            DotShape(text: text, colons: false).fill(color)
            if text.contains(":") {
                DotShape(text: text, colons: true).fill(colonOn ? color : color.opacity(0.15))
            }
        }
        .frame(width: CGFloat(DotShape.columns(text)) * pitch, height: 7 * pitch)
    }
}

private struct DotMatrixFace: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.previewConfig) private var preview
    private var cfg: ClockConfig { preview ?? settings.config }
    let t: TimeParts, p: Palette, size: CGFloat

    var body: some View {
        let pitch = size * 1.2 / 7
        // 12-hour time drops the leading zero, like a bedside clock.
        let hour = t.ampm != nil && t.hour.hasPrefix("0") ? String(t.hour.dropFirst()) : t.hour
        VStack(spacing: size * 0.22) {
            HStack(alignment: .bottom, spacing: pitch * 1.6) {
                DotText(text: "\(hour):\(t.minute)", color: p.digit, pitch: pitch, colonOn: t.colonOn)
                if cfg.showSeconds || t.ampm != nil {
                    VStack(alignment: .leading, spacing: 0) {
                        if let ampm = t.ampm {
                            DotText(text: ampm, color: p.digit, pitch: pitch * 0.32)
                        }
                        Spacer(minLength: 0)
                        if cfg.showSeconds {
                            DotText(text: t.second, color: p.digit, pitch: pitch * 0.58)
                        }
                    }
                    .frame(height: 7 * pitch)
                }
            }
            if cfg.showDate {
                Text(t.date.uppercased())
                    .font(cfg.typeface(size * 0.3, weight: .medium))
                    .tracking(size * 0.06)
                    .foregroundStyle(p.digit.opacity(0.85))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

// MARK: - Analog

private struct TickShape: Shape {
    let major: Bool
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<60 where (i % 5 == 0) == major {
            let a = Double(i) / 60 * 2 * .pi
            let outer = r * 0.92, inner = r * (major ? 0.8 : 0.86)
            p.move(to: CGPoint(x: c.x + sin(a) * inner, y: c.y - cos(a) * inner))
            p.addLine(to: CGPoint(x: c.x + sin(a) * outer, y: c.y - cos(a) * outer))
        }
        return p
    }
}

private struct HandShape: Shape {
    var fraction: Double
    let length: CGFloat
    let tail: CGFloat
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let a = fraction * 2 * .pi
        var p = Path()
        p.move(to: CGPoint(x: c.x - sin(a) * r * tail, y: c.y + cos(a) * r * tail))
        p.addLine(to: CGPoint(x: c.x + sin(a) * r * length, y: c.y - cos(a) * r * length))
        return p
    }
}

private struct AnalogFace: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.previewConfig) private var preview
    private var cfg: ClockConfig { preview ?? settings.config }
    let t: TimeParts, p: Palette, size: CGFloat

    var body: some View {
        let d = size * 2.6
        let r = d / 2
        let font = cfg.typeface(d * 0.11, weight: .semibold)
        let sec = Double(t.s), min = Double(t.m) + sec / 60, hr = Double(t.h % 12) + min / 60
        VStack(spacing: size * 0.16) {
            ZStack {
                Circle()
                    .fill(p.card)
                    .shadow(color: .black.opacity(0.16), radius: size * 0.08, y: size * 0.03)
                TickShape(major: false)
                    .stroke(p.digit.opacity(0.3), style: StrokeStyle(lineWidth: r * 0.012, lineCap: .round))
                TickShape(major: true)
                    .stroke(p.digit.opacity(0.9), style: StrokeStyle(lineWidth: r * 0.03, lineCap: .round))
                ForEach([12, 3, 6, 9], id: \.self) { n in
                    let a = Double(n) / 12 * 2 * .pi
                    Text("\(n)").font(font).foregroundStyle(p.digit)
                        .position(x: r + sin(a) * r * 0.64, y: r - cos(a) * r * 0.64)
                }
                HandShape(fraction: hr / 12, length: 0.5, tail: 0.1)
                    .stroke(p.digit, style: StrokeStyle(lineWidth: r * 0.07, lineCap: .round))
                HandShape(fraction: min / 60, length: 0.75, tail: 0.1)
                    .stroke(p.digit, style: StrokeStyle(lineWidth: r * 0.05, lineCap: .round))
                if cfg.showSeconds {
                    HandShape(fraction: sec / 60, length: 0.84, tail: 0.18)
                        .stroke(p.accent, style: StrokeStyle(lineWidth: r * 0.02, lineCap: .round))
                }
                Circle().fill(p.accent).frame(width: r * 0.14, height: r * 0.14)
            }
            .frame(width: d, height: d)

            DateLine(t: t, p: p, size: size)
        }
    }
}

// MARK: - Shared

private struct DateLine: View {
    @Environment(ClockSettings.self) private var settings
    @Environment(\.previewConfig) private var preview
    private var cfg: ClockConfig { preview ?? settings.config }
    let t: TimeParts, p: Palette, size: CGFloat

    var body: some View {
        if cfg.showDate {
            Text(t.date)
                .font(cfg.typeface(size * 0.22, weight: .medium))
                .foregroundStyle(p.digit.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
        }
    }
}
