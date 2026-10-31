import CoreGraphics
import Foundation
// scroll x y dy count [dx]: posts `count` precise (pixel) scroll events of dy (and optionally dx) points at (x, y)
let p = CGPoint(x: Double(CommandLine.arguments[1])!, y: Double(CommandLine.arguments[2])!)
let dy = Int32(CommandLine.arguments[3])!, count = Int(CommandLine.arguments[4])!
let dx = CommandLine.arguments.count > 5 ? Int32(CommandLine.arguments[5])! : 0
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(150_000)
for _ in 0..<count {
    let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)
    e?.location = p
    e?.post(tap: .cghidEventTap)
    usleep(30_000)
}
