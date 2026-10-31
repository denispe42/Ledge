import AppKit
// sheet <out.png> <cols> <file>... : labelled contact sheet
let args = CommandLine.arguments
let out = args[1], cols = Int(args[2])!, files = Array(args[3...])
let imgs = files.compactMap { NSImage(contentsOfFile: $0) }
let w = 590.0, h = 220.0, scale = 0.6
let cw = w*scale, ch = h*scale + 16
let rows = (imgs.count + cols - 1) / cols
let sheet = NSImage(size: NSSize(width: cw*Double(cols), height: ch*Double(rows)))
sheet.lockFocus()
NSColor.darkGray.setFill(); NSRect(x: 0, y: 0, width: sheet.size.width, height: sheet.size.height).fill()
for (i, img) in imgs.enumerated() {
    let x = Double(i % cols) * cw, y = sheet.size.height - Double(i / cols + 1) * ch
    img.draw(in: NSRect(x: x, y: y, width: cw, height: h*scale))
    let label = (files[i] as NSString).lastPathComponent.components(separatedBy: "_").last ?? ""
    (label as NSString).draw(at: NSPoint(x: x + 4, y: y + h*scale + 1), withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 11)])
}
sheet.unlockFocus()
let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
