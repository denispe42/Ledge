import CoreGraphics
import Foundation
let p = CGPoint(x: Double(CommandLine.arguments[1])!, y: Double(CommandLine.arguments[2])!)
for t in [CGEventType.leftMouseDown, .leftMouseUp] {
    CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(60000)
}
