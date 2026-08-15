import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let out = args[1]
let cols = Int(args[2])!
let paths = Array(args[3...])
let cellW = 620
func load(_ p: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}
let imgs = paths.map { load($0) }
let first = imgs.compactMap { $0 }.first!
let cellH = Int(Double(cellW) * Double(first.height) / Double(first.width))
let rows = (paths.count + cols - 1) / cols
let W = cols * cellW, H = rows * cellH
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
for (i, img) in imgs.enumerated() {
    guard let img = img else { continue }
    let col = i % cols, row = i / cols
    ctx.draw(img, in: CGRect(x: col * cellW, y: H - (row + 1) * cellH, width: cellW, height: cellH))
}
let outImg = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, outImg, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
CGImageDestinationFinalize(dest)
print("wrote \(out) \(W)x\(H)")
