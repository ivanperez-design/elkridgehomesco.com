import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import CoreVideo

// args: out.mp4  W  H  slotSeconds  panBias  img1 img2 ...
let a = CommandLine.arguments
let outPath = a[1]
let W = Int(a[2])!, H = Int(a[3])!
let slot = Double(a[4])!
let panBias = Double(a[5])!
let paths = Array(a[6...])
let n = paths.count
let fps = 30.0
let tw = 1.05                 // build-up reveal window (longer = more visible "rising")
let total = Double(n) * slot
let totalFrames = Int(total * fps)

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
        AVVideoAverageBitRateKey: 3_600_000,
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

// draw image aspect-fill with subtle ken-burns zoom kb (0..1) + global alpha
func draw(_ ctx: CGContext, _ img: CGImage, _ kb: Double, _ alpha: Double) {
    let iw = Double(img.width), ih = Double(img.height)
    let canvasAR = Double(W) / Double(H), imgAR = iw / ih
    var dw: Double, dh: Double
    if imgAR > canvasAR { dh = Double(H); dw = dh * imgAR } else { dw = Double(W); dh = dw / imgAR }
    let z = 1.0 + 0.06 * kb
    dw *= z; dh *= z
    let x = (Double(W) - dw) / 2 + panBias - 5.0 * kb
    let y = (Double(H) - dh) / 2
    ctx.saveGState()
    ctx.setAlpha(CGFloat(alpha))
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: x, y: y, width: dw, height: dh))
    ctx.restoreGState()
}

// reveal `img` from the BOTTOM up to fraction r (0..1). y=0 is bottom in this context.
func drawRising(_ ctx: CGContext, _ img: CGImage, _ kb: Double, _ r: Double) {
    let revealH = max(1.0, Double(H) * r)
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: Double(W), height: revealH))   // bottom band grows up
    draw(ctx, img, kb, 1.0)
    ctx.restoreGState()
    // soft global dissolve so the rising edge isn't a hard line and the top blends in
    draw(ctx, img, kb, r * 0.28)
}

func easeInOut(_ t: Double) -> Double { t < 0.5 ? 2*t*t : 1 - pow(-2*t+2, 2)/2 }

for f in 0..<totalFrames {
    let t = Double(f) / fps
    var s = Int(t / slot); if s >= n { s = n - 1 }
    let localT = t - Double(s) * slot
    let kbCur = min(1.0, localT / slot)
    var pb: CVPixelBuffer?
    if let pool = adaptor.pixelBufferPool {
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
    } else {
        CVPixelBufferCreate(kCFAllocatorDefault, W, H, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
    }
    guard let buf = pb else { continue }
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: H, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    draw(ctx, imgs[s], kbCur, 1.0)
    if s < n - 1 && localT > slot - tw {
        let r = easeInOut((localT - (slot - tw)) / tw)   // 0..1 rising reveal of next stage
        drawRising(ctx, imgs[s + 1], 0.0, r)
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
