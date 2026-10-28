import AppKit
import ImageIO
import UniformTypeIdentifiers
// Builds an animated GIF from exported frames: make-gif <out.gif> <fps> <width> <frames dir> [step] [firstIndex] [lastIndex]
// Keeps every `step`-th PNG (sorted by name) between the two indexes and scales it to `width` pixels.
// Optional environment variable GIF_CROP="x,y,w,h" (pixels of the source frames) crops each frame first.
let args = CommandLine.arguments
guard args.count >= 5, let fps = Double(args[2]), let width = Int(args[3]) else { print("usage"); exit(1) }
let step = args.count > 5 ? Int(args[5]) ?? 1 : 1
let files = ((try? FileManager.default.contentsOfDirectory(atPath: args[4])) ?? []).filter { $0.hasSuffix(".png") }.sorted()
let first = args.count > 6 ? Int(args[6]) ?? 0 : 0
let last = args.count > 7 ? min(Int(args[7]) ?? files.count - 1, files.count - 1) : files.count - 1
let picked = stride(from: first, through: last, by: step).map { files[$0] }
guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, UTType.gif.identifier as CFString, picked.count, nil) else { exit(1) }
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
for name in picked {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[4] + "/" + name) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
    var frame = image
    if let crop = ProcessInfo.processInfo.environment["GIF_CROP"]?.split(separator: ",").compactMap({ Double($0) }), crop.count == 4,
       let cropped = image.cropping(to: CGRect(x: crop[0], y: crop[1], width: crop[2], height: crop[3])) { frame = cropped }
    let height = Int(Double(frame.height) * Double(width) / Double(frame.width))
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let scaled = context.makeImage() else { continue }
    CGImageDestinationAddImage(destination, scaled, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 1.0 / fps]] as CFDictionary)
}
print(CGImageDestinationFinalize(destination) ? "gif: \(picked.count) frames" : "failed")
