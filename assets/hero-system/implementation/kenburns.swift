import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import CoreVideo

// ONE continuous cinematic film from locked-camera build keyframes.
// All build stages share the same camera, so a SINGLE global push-in across the
// whole timeline + long cross-dissolves makes the home MATERIALIZE stage by stage
// under one unbroken camera move (reads as a build happening, not a slideshow).
// The final still (aerial reveal) does a drone PULL-BACK instead.
//
// args: out.mp4  W  H  perStillSeconds  xfadeSeconds  img1 .. imgN   (last img = aerial reveal)
let a = CommandLine.arguments
guard a.count >= 7 else { fputs("usage: kenburns out W H slot xfade imgs...\n", stderr); exit(2) }
let outPath = a[1]
let W = Int(a[2])!, H = Int(a[3])!
let slot = Double(a[4])!
let xfade = Double(a[5])!
let paths = Array(a[6...])
let n = paths.count
let fps = 30.0
let step = slot - xfade
let total = Double(n) * slot - Double(n - 1) * xfade
let totalFrames = Int(total * fps)
let buildEnd = Double(n - 1) * step + slot      // end time of the last BUILD still (index n-2)
let zStart = 1.02, zEnd = 1.20                  // global continuous push-in across the build

func loadCG(_ p: String) -> CGImage? {
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(s, 0, nil)
}
let imgs = paths.map { loadCG($0)! }

try? FileManager.default.removeItem(atPath: outPath)
let writer = try! AVAssetWriter(outputURL: URL(fileURLWithPath: outPath), fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 3_800_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: 60
    ]
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let attrs: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
    kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
    kCVPixelBufferIOSurfacePropertiesKey as String: [:]
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func easeInOut(_ t: Double) -> Double { t < 0.5 ? 2*t*t : 1 - pow(-2*t+2, 2)/2 }

func draw(_ ctx: CGContext, _ img: CGImage, zoom: Double, pany: Double, alpha: Double) {
    let iw = Double(img.width), ih = Double(img.height)
    let canvasAR = Double(W) / Double(H), imgAR = iw / ih
    var dw: Double, dh: Double
    if imgAR > canvasAR { dh = Double(H); dw = dh * imgAR } else { dw = Double(W); dh = dw / imgAR }
    dw *= zoom; dh *= zoom
    let slackY = (dh - Double(H)) / 2.0
    let x = (Double(W) - dw) / 2
    let y = (Double(H) - dh) / 2 + pany * slackY
    ctx.saveGState()
    ctx.setAlpha(CGFloat(alpha))
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: x, y: y, width: dw, height: dh))
    ctx.restoreGState()
}

for f in 0..<totalFrames {
    let t = Double(f) / fps
    var pb: CVPixelBuffer?
    if let pool = adaptor.pixelBufferPool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) }
    else { CVPixelBufferCreate(kCFAllocatorDefault, W, H, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb) }
    guard let buf = pb else { continue }
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: H, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    // global continuous push for the build (shared by all locked-camera stills)
    let gp = max(0.0, min(1.0, t / buildEnd))
    let globalZoom = zStart + (zEnd - zStart) * gp

    for i in 0..<n {
        let startT = Double(i) * step
        let endT = startT + slot
        if t < startT - 0.0001 || t > endT + 0.0001 { continue }
        var alpha = 1.0
        if i > 0 && (t - startT) < xfade { alpha = easeInOut((t - startT) / xfade) }
        if i < n - 1 && (endT - t) < xfade { alpha = min(alpha, easeInOut((endT - t) / xfade)) }
        var zoom = globalZoom
        var pany = 0.06 - 0.12 * gp            // very gentle settle
        if i == n - 1 {                         // aerial reveal: drone pull-back
            let lp = max(0.0, min(1.0, (t - startT) / slot))
            zoom = 1.24 - 0.24 * easeInOut(lp)  // 1.24 -> 1.0 (pull back to reveal)
            pany = 0.0
        }
        draw(ctx, imgs[i], zoom: zoom, pany: pany, alpha: alpha)
    }
    CVPixelBufferUnlockBaseAddress(buf, [])
    while !input.isReadyForMoreMediaData { usleep(2000) }
    adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: CMTimeScale(fps)))
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print("wrote \(outPath) \(W)x\(H) frames=\(totalFrames) dur=\(String(format: "%.1f", total))s status=\(writer.status.rawValue)")
