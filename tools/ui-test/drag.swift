import CoreGraphics
import Foundation
// drag x1 y1 x2 y2 [holdMs [x3 y3]]: mouse down at 1, move in small steps to 2 (a real drag session starts in the app
// under the pointer, e.g. Finder), wait holdMs over the target, mouse up. With x3 y3 the drag continues to 3 after the
// wait (the island opens at 2, a zone inside it is at 3) and is released there.
let a = CommandLine.arguments.dropFirst().compactMap { Double($0) }
guard a.count >= 4 else { print("usage: drag x1 y1 x2 y2 [holdMs]"); exit(1) }
let from = CGPoint(x: a[0], y: a[1]), to = CGPoint(x: a[2], y: a[3])
let hold = a.count > 4 ? UInt32(a[4]) : 600
func post(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}
post(.mouseMoved, from); usleep(300_000)
post(.leftMouseDown, from); usleep(200_000)
func move(from: CGPoint, to: CGPoint) {
    let steps = 40
    for i in 1...steps {
        let t = Double(i) / Double(steps)
        post(.leftMouseDragged, CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
        usleep(15_000)
    }
}
move(from: from, to: to)
usleep(hold * 1000)
var end = to
if a.count >= 7 {
    end = CGPoint(x: a[5], y: a[6])
    move(from: to, to: end)
    usleep(600_000)
}
post(.leftMouseUp, end)
