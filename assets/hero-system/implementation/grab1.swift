import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let path = args[1], out = args[2]
let cols = 4, rows = 3, n = 12, cellW = 320
let url = URL(fileURLWithPath: path)
let asset = AVURLAsset(url: url)
let dur = CMTimeGetSeconds(asset.duration)
guard let track = asset.tracks(withMediaType: .video).first else { print("no track"); exit(1) }
let sz = track.naturalSize.applying(track.preferredTransform)
let vw = abs(sz.width), vh = abs(sz.height)
print("dur=\(String(format: "%.2f", dur))s \(Int(vw))x\(Int(vh))")
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = CMTime(seconds: 0.04, preferredTimescale: 600)
let cellH = Int(Double(cellW) * vh / vw)
let W = cols * cellW, H = rows * cellH
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
for i in 0..<n {
    let frac = (Double(i) + 0.5) / Double(n) * 0.97 + 0.015
    let t = CMTime(seconds: dur * frac, preferredTimescale: 600)
    guard let img = try? gen.copyCGImage(at: t, actualTime: nil) else { continue }
    let col = i % cols, row = i / cols
    ctx.draw(img, in: CGRect(x: col * cellW, y: H - (row + 1) * cellH, width: cellW, height: cellH))
}
let outImg = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, outImg, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
CGImageDestinationFinalize(dest)
print("-> \(out)")
