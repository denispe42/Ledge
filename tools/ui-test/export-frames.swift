import AVFoundation
import AppKit
// Exports every frame of a recording to PNG with its timestamp in ms: export <mov> <outdir>
let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
let outDir = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let sem = DispatchSemaphore(value: 0)
Task {
    let track = try! await asset.loadTracks(withMediaType: .video).first!
    let reader = try! AVAssetReader(asset: asset)
    let out = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(out); reader.startReading()
    var t0: Double?
    var n = 0
    while let sb = out.copyNextSampleBuffer() {
        let t = CMSampleBufferGetPresentationTimeStamp(sb).seconds
        if t0 == nil { t0 = t }
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
        let img = CIImage(cvPixelBuffer: pb)
        let rep = NSBitmapImageRep(ciImage: img)
        let data = rep.representation(using: .png, properties: [:])!
        try! data.write(to: URL(fileURLWithPath: String(format: "%@/f%03d_%04dms.png", outDir, n, Int((t - t0!) * 1000))))
        n += 1
    }
    print("frames: \(n)")
    sem.signal()
}
sem.wait()
