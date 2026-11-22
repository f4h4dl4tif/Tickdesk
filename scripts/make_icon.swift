import AppKit
// Renders a flip-card style icon to the given PNG path at 1024px.
let out = CommandLine.arguments[1]
let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
    let bg = NSBezierPath(roundedRect: r.insetBy(dx: 90, dy: 90), xRadius: 190, yRadius: 190)
    NSGradient(starting: NSColor(calibratedWhite: 0.20, alpha: 1), ending: NSColor(calibratedWhite: 0.07, alpha: 1))!.draw(in: bg, angle: -90)
    let cardW = 330.0, cardH = 420.0, gap = 36.0
    let x0 = (size - (cardW * 2 + gap)) / 2, y0 = (size - cardH) / 2 + 20
    let font = NSFont.systemFont(ofSize: 300, weight: .bold)
    let desc = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
    let rounded = NSFont(descriptor: desc, size: 300) ?? font
    for (i, t) in ["1", "2"].enumerated() {
        let rect = NSRect(x: x0 + Double(i) * (cardW + gap), y: y0, width: cardW, height: cardH)
        NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 56, yRadius: 56).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: rounded, .foregroundColor: NSColor(calibratedWhite: 0.11, alpha: 1)]
        let s = NSAttributedString(string: t == "1" ? "09" : "41", attributes: attrs)
        let ss = s.size()
        let scale = min(1, (cardW - 30) / ss.width)
        let a2: [NSAttributedString.Key: Any] = [.font: NSFont(descriptor: desc, size: 300 * scale) ?? rounded, .foregroundColor: NSColor(calibratedWhite: 0.11, alpha: 1)]
        let s2 = NSAttributedString(string: s.string, attributes: a2)
        let sz = s2.size()
        s2.draw(at: NSPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2))
        NSColor(calibratedWhite: 0.12, alpha: 0.55).setFill()
        NSRect(x: rect.minX, y: rect.midY - 5, width: cardW, height: 10).fill()
    }
    NSColor(calibratedRed: 1, green: 0.27, blue: 0.23, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: size / 2 - 26, y: 210, width: 52, height: 52)).fill()
    return true
}
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
