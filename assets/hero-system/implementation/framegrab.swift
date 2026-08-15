import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let cols = 4, rows = 3
let n = cols * rows
let cellW = 300

func sheet(_ path: String, _ out: String) {
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    let dur = CMTimeGetSeconds(asset.duration)
    guard let track = asset.tracks(withMediaType: .video).first else { print("\(path): no video track"); return }
    let sz = track.naturalSize.applying(track.preferredTransform)
    let vw = abs(sz.width), vh = abs(sz.height)
    print("\(path): dur=\(String(format: "%.2f", dur))s  \(Int(vw))x\(Int(vh))")
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
    let cellH = Int(Double(cellW) * vh / vw)
    let W = cols * cellW, H = rows * cellH
    guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for i in 0..<n {
        let frac = (Double(i) + 0.5) / Double(n) * 0.96 + 0.02
        let t = CMTime(seconds: dur * frac, preferredTimescale: 600)
        guard let img = try? gen.copyCGImage(at: t, actualTime: nil) else { continue }
        let col = i % cols, row = i / cols
        let x = col * cellW
        let y = H - (row + 1) * cellH  // CG origin bottom-left -> row 0 on top
        ctx.draw(img, in: CGRect(x: x, y: y, width: cellW, height: cellH))
    }
    guard let outImg = ctx.makeImage() else { return }
    let outURL = URL(fileURLWithPath: out)
    guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, outImg, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
    CGImageDestinationFinalize(dest)
    print("  -> \(out)")
}

for v in ["p1", "p2", "p3"] {
    sheet("/tmp/polidori/\(v).mp4", "/tmp/polidori/sheet_\(v).jpg")
}
