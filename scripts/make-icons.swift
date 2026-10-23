// Draws the LTRF Labs neon style icons into LTRFNet/Assets.xcassets: swift scripts/make-icons.swift
import AppKit

let assets = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "LTRFNet/Assets.xcassets")
let green = CGColor(red: 0.22, green: 1.0, blue: 0.45, alpha: 1)
let cyan = CGColor(red: 0.35, green: 0.95, blue: 1.0, alpha: 1)

/// Strokes `path` as a neon tube: a wide soft glow, then a gradient core with a white hot center.
func neon(_ cg: CGContext, _ path: CGPath, width: CGFloat, from: CGColor = green, to: CGColor = cyan) {
    let box = path.boundingBoxOfPath.insetBy(dx: -width, dy: -width)
    let gradient = CGGradient(colorsSpace: nil, colors: [from, to] as CFArray, locations: nil)!
    for (blur, alpha) in [(width * 3, 0.55), (width * 1.2, 0.9)] {
        cg.saveGState()
        cg.setShadow(offset: .zero, blur: blur, color: from.copy(alpha: alpha))
        cg.addPath(path); cg.setLineWidth(width); cg.setLineCap(.round); cg.setLineJoin(.round)
        cg.setStrokeColor(to.copy(alpha: 0.6)!); cg.strokePath()
        cg.restoreGState()
    }
    cg.saveGState()
    cg.addPath(path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)); cg.clip()
    cg.drawLinearGradient(gradient, start: CGPoint(x: box.minX, y: box.maxY), end: CGPoint(x: box.maxX, y: box.minY), options: [])
    cg.restoreGState()
    cg.addPath(path); cg.setLineWidth(width * 0.3); cg.setStrokeColor(CGColor(gray: 1, alpha: 0.7)); cg.strokePath()
}

/// "LTRF" as rounded line letters, `h` high, with the top left corner at `origin` (y grows down).
func letters(at origin: CGPoint, h: CGFloat) -> CGPath {
    let w = h * 0.8, gap = h * 0.17, mid = h * 0.5, r = mid / 2
    let p = CGMutablePath()
    var x = origin.x
    let top = origin.y, bottom = origin.y + h
    // L
    p.move(to: CGPoint(x: x, y: top)); p.addLine(to: CGPoint(x: x, y: bottom)); p.addLine(to: CGPoint(x: x + w, y: bottom))
    x += w + gap
    // T
    p.move(to: CGPoint(x: x, y: top)); p.addLine(to: CGPoint(x: x + w, y: top))
    p.move(to: CGPoint(x: x + w / 2, y: top)); p.addLine(to: CGPoint(x: x + w / 2, y: bottom))
    x += w + gap
    // R
    p.move(to: CGPoint(x: x, y: bottom)); p.addLine(to: CGPoint(x: x, y: top)); p.addLine(to: CGPoint(x: x + w - r, y: top))
    p.addArc(center: CGPoint(x: x + w - r, y: top + r), radius: r, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
    p.addLine(to: CGPoint(x: x, y: top + mid))
    p.move(to: CGPoint(x: x + w * 0.5, y: top + mid)); p.addLine(to: CGPoint(x: x + w, y: bottom))
    x += w + gap
    // F
    p.move(to: CGPoint(x: x + w, y: top)); p.addLine(to: CGPoint(x: x, y: top)); p.addLine(to: CGPoint(x: x, y: bottom))
    p.move(to: CGPoint(x: x, y: top + mid)); p.addLine(to: CGPoint(x: x + w * 0.75, y: top + mid))
    return p
}

func arc(_ c: CGPoint, _ r: CGFloat, _ from: CGFloat, _ to: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.addArc(center: c, radius: r, startAngle: from * .pi / 180, endAngle: to * .pi / 180, clockwise: false)
    return p
}

/// The 1024 × 1024 app icon: a black macOS rounded square with the neon ring, "LTRF" and "Net".
func appIcon() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cg = NSGraphicsContext.current!.cgContext
    cg.translateBy(x: 0, y: 1024); cg.scaleBy(x: 1, y: -1)  // y grows down
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    cg.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)); cg.clip()
    cg.drawRadialGradient(CGGradient(colorsSpace: nil, colors: [CGColor(red: 0.03, green: 0.09, blue: 0.08, alpha: 1), CGColor(gray: 0, alpha: 1)] as CFArray, locations: nil)!,
                          startCenter: CGPoint(x: 512, y: 512), startRadius: 0, endCenter: CGPoint(x: 512, y: 512), endRadius: 460, options: .drawsAfterEndLocation)
    let c = CGPoint(x: 512, y: 512)
    neon(cg, arc(c, 360, -10, 320), width: 14)  // the outer ring, open where "Net" sits
    neon(cg, arc(c, 322, 200, 290), width: 9)   // the inner arcs
    neon(cg, arc(c, 322, 20, 95), width: 9)
    neon(cg, letters(at: CGPoint(x: 512 - 236, y: 420), h: 120), width: 20)
    let net = NSAttributedString(string: "Net", attributes: [
        .font: NSFont(descriptor: NSFont.systemFont(ofSize: 92, weight: .semibold).fontDescriptor.withDesign(.rounded)!, size: 92)!,
        .foregroundColor: NSColor(cgColor: cyan)!,
    ])
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowBlurRadius = 24; shadow.shadowColor = NSColor(cgColor: cyan); shadow.set()
    cg.saveGState(); cg.translateBy(x: 0, y: 1024); cg.scaleBy(x: 1, y: -1)  // text draws with y up
    net.draw(at: CGPoint(x: 600, y: 1024 - 680))
    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// The 18 pt menu bar template: the open ring and a three-node mesh, slashed when not `on`.
func menuIcon(on: Bool) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 18, height: 18)
    let cg = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
    cg.beginPDFPage(nil)
    cg.setStrokeColor(CGColor(gray: 0, alpha: 1)); cg.setFillColor(CGColor(gray: 0, alpha: 1))
    cg.setLineCap(.round)
    let slash = CGMutablePath()
    slash.move(to: CGPoint(x: 2.5, y: 15.5)); slash.addLine(to: CGPoint(x: 15.5, y: 2.5))
    if !on {
        // Cut a gap around the slash out of the drawing under it.
        cg.addRect(box); cg.addPath(slash.copy(strokingWithWidth: 3.8, lineCap: .round, lineJoin: .round, miterLimit: 10))
        cg.clip(using: .evenOdd)
    }
    cg.setLineWidth(1.6)
    cg.addPath(arc(CGPoint(x: 9, y: 9), 7.6, 40, 340)); cg.strokePath()
    let nodes = [CGPoint(x: 6, y: 11.8), CGPoint(x: 11.8, y: 10.6), CGPoint(x: 7.6, y: 5.6)]
    cg.setLineWidth(1.1)
    cg.addLines(between: nodes + [nodes[0]]); cg.strokePath()
    for n in nodes { cg.fillEllipse(in: CGRect(x: n.x - 1.7, y: n.y - 1.7, width: 3.4, height: 3.4)) }
    if !on {
        cg.resetClip(); cg.setLineWidth(1.6); cg.addPath(slash); cg.strokePath()
    }
    cg.endPDFPage(); cg.closePDF()
    return data as Data
}

func write(_ json: String, to dir: URL) throws {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

try write(#"{"info":{"author":"xcode","version":1}}"#, to: assets)

let icons = assets.appendingPathComponent("AppIcon.appiconset")
let master = appIcon()
var images: [String] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale, name = "icon_\(size)x\(size)@\(scale)x.png"
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current!.imageInterpolation = .high
        master.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
        try rep.representation(using: .png, properties: [:])!.write(to: icons.appendingPathComponent(name))
        images.append(#"{"filename":"\#(name)","idiom":"mac","scale":"\#(scale)x","size":"\#(size)x\#(size)"}"#)
    }
}
try write(#"{"images":[\#(images.joined(separator: ","))],"info":{"author":"xcode","version":1}}"#, to: icons)

for (name, on) in [("MenuOn", true), ("MenuOff", false)] {
    let set = assets.appendingPathComponent("\(name).imageset")
    try write(#"{"images":[{"filename":"\#(name).pdf","idiom":"universal"}],"info":{"author":"xcode","version":1},"properties":{"preserves-vector-representation":true,"template-rendering-intent":"template"}}"#, to: set)
    try menuIcon(on: on).write(to: set.appendingPathComponent("\(name).pdf"))
}
