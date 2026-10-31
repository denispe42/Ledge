import AppKit
// lum <dir>: mean brightness of the island area (x 150..440 pt, y 0..140 pt of the 590x220 strip) per frame
let dir = CommandLine.arguments[1]
let files = (try! FileManager.default.contentsOfDirectory(atPath: dir)).filter { $0.hasSuffix(".png") }.sorted()
var prev = -1.0
for f in files {
    guard let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "\(dir)/\(f)"))) else { continue }
    let s = Double(rep.pixelsWide) / 590.0
    var sum = 0.0, n = 0.0
    for y in stride(from: 0, to: Int(140*s), by: 4) { for x in stride(from: Int(150*s), to: Int(440*s), by: 4) {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        sum += Double(c.redComponent + c.greenComponent + c.blueComponent) / 3; n += 1 } }
    let m = sum / n
    if abs(m - prev) > 0.004 { print(String(format: "%@  mean=%.3f", f, m)) }
    prev = m
}
