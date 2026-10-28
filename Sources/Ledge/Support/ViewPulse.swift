import AppKit

extension NSView {
    /// A short swell of the view around its centre, used to draw the eye (skipped with Reduce Motion).
    func pulse(scale: CGFloat = 1.3, duration: CFTimeInterval = 0.22) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        wantsLayer = true
        guard let layer else { return }
        let b = layer.bounds
        var peak = CATransform3DMakeTranslation(b.midX, b.midY, 0)
        peak = CATransform3DScale(peak, scale, scale, 1)
        peak = CATransform3DTranslate(peak, -b.midX, -b.midY, 0)
        let swell = CABasicAnimation(keyPath: "transform")
        swell.fromValue = CATransform3DIdentity
        swell.toValue = peak
        swell.duration = duration
        swell.autoreverses = true
        swell.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(swell, forKey: "pulse")
    }
}

extension CALayer {
    /// `build` applied to a transform about the layer's centre, whatever the layer's anchor point is.
    func aboutCenter(_ build: (CATransform3D) -> CATransform3D) -> CATransform3D {
        let cx = bounds.midX - anchorPoint.x * bounds.width
        let cy = bounds.midY - anchorPoint.y * bounds.height
        return CATransform3DTranslate(build(CATransform3DMakeTranslation(cx, cy, 0)), -cx, -cy, 0)
    }
}
