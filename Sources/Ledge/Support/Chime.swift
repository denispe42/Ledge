import AppKit

/// The sound that announces the end of a timer: the chosen system sound, repeated a few times.
/// The sound object is kept alive while it plays (a released NSSound stays silent), and each repeat starts when the
/// previous one has finished, so there is no timer polling.
@MainActor
final class Chime: NSObject, NSSoundDelegate {
    static let shared = Chime()

    private var sound: NSSound?
    private var repeatsLeft = 0
    private var completion: (() -> Void)?
    private var onBeat: (() -> Void)?

    /// Plays `name` `times` times in a row. Falls back to the system beep if the sound cannot be played.
    /// `completion` runs once when the last repeat has finished (or the beep fallback was used); `stop()` drops it.
    /// `onBeat` runs each time a repeat starts, so the UI can pulse in time with the sound.
    func play(named name: String, times: Int = 3, onBeat: (() -> Void)? = nil, completion: (() -> Void)? = nil) {
        stop()
        self.completion = completion
        self.onBeat = onBeat
        let path = "\(TimerSettings.soundDirectory)/\(name).aiff"
        guard let sound = NSSound(contentsOf: URL(fileURLWithPath: path), byReference: true) ?? NSSound(named: name) else {
            NSSound.beep()
            finish()
            return
        }
        sound.delegate = self
        self.sound = sound
        repeatsLeft = max(0, times - 1)
        if sound.play() {
            onBeat?()
        } else {
            self.sound = nil
            NSSound.beep()
            finish()
        }
    }

    func stop() {
        completion = nil
        onBeat = nil
        repeatsLeft = 0
        sound?.delegate = nil
        sound?.stop()
        sound = nil
    }

    func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        guard sound === self.sound else { return }
        guard repeatsLeft > 0 else { self.sound = nil; finish(); return }
        repeatsLeft -= 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, let current = self.sound else { return }
            if current.play() { self.onBeat?() } else { self.sound = nil; self.finish() }
        }
    }

    private func finish() {
        let done = completion
        completion = nil
        onBeat = nil
        done?()
    }
}
