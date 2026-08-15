import Foundation
import AVFoundation
import CoreMedia

// Crossfade-concatenate N video clips into one continuous hero.
// Each clip ends on the same keyframe the next clip begins on, so the
// dissolve reads as an invisible match cut (one connected sequence).
//
// args: out.mp4  W  H  slotSeconds  xfadeSeconds  clip1 clip2 ...
let a = CommandLine.arguments
guard a.count >= 7 else { fputs("usage: assemble out W H slot xfade clips...\n", stderr); exit(2) }
let outPath = a[1]
let W = Int(a[2])!, H = Int(a[3])!
let slot = Double(a[4])!          // seconds taken from each clip (from its start)
let xfade = Double(a[5])!         // crossfade duration between clips
var clipPaths = Array(a[6...])
let fps: Int32 = 30
let ts: Int32 = 600
let xfadeT = CMTime(seconds: xfade, preferredTimescale: ts)

// LOOP MODE: trailing "loop" sentinel → append the FIRST clip's head as a final
// crossfade target, so the film dissolves back to its opening frame (seamless loop).
var loopMode = false
if clipPaths.last == "loop" { loopMode = true; clipPaths.removeLast() }
let firstClip = clipPaths.first!
if loopMode { clipPaths.append(firstClip) }           // loop-head appended last
let loopHeadIdx = clipPaths.count - 1
// per-clip take: normal slot, except the appended loop-head gets just the dissolve + a hair
func slotFor(_ i: Int) -> Double { (loopMode && i == loopHeadIdx) ? (xfade + 0.3) : slot }

let comp = AVMutableComposition()
let trackA = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
let trackB = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
let tracks = [trackA, trackB]

struct Seg { let track: AVMutableCompositionTrack; let start: CMTime; let dur: CMTime; let natSize: CGSize; let pref: CGAffineTransform }
var segs: [Seg] = []
var cursor = CMTime.zero

for (i, p) in clipPaths.enumerated() {
    let asset = AVURLAsset(url: URL(fileURLWithPath: p))
    guard let vt = asset.tracks(withMediaType: .video).first else { fputs("no video track in \(p)\n", stderr); exit(3) }
    let clipDur = CMTimeGetSeconds(asset.duration)
    let take = min(slotFor(i), clipDur)
    let takeT = CMTime(seconds: take, preferredTimescale: ts)
    let track = tracks[i % 2]
    do {
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: takeT), of: vt, at: cursor)
    } catch { fputs("insert failed \(p): \(error)\n", stderr); exit(4) }
    segs.append(Seg(track: track, start: cursor, dur: takeT, natSize: vt.naturalSize, pref: vt.preferredTransform))
    cursor = CMTimeAdd(cursor, takeT)
    if i < clipPaths.count - 1 { cursor = CMTimeSubtract(cursor, xfadeT) }
}
let totalDur = cursor

// aspect-fill transform: scale source (after preferred transform) to cover WxH, centered
func fillTransform(_ natSize: CGSize, _ pref: CGAffineTransform) -> CGAffineTransform {
    var t = pref
    let post0 = CGRect(origin: .zero, size: natSize).applying(t)
    let dispW = abs(post0.width), dispH = abs(post0.height)
    let scale = max(Double(W) / Double(dispW), Double(H) / Double(dispH))
    t = t.concatenating(CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
    let post = CGRect(origin: .zero, size: natSize).applying(t)
    let tx = (CGFloat(W) - post.width) / 2.0 - post.minX
    let ty = (CGFloat(H) - post.height) / 2.0 - post.minY
    return t.concatenating(CGAffineTransform(translationX: tx, y: ty))
}

func layerInstr(_ s: Seg) -> AVMutableVideoCompositionLayerInstruction {
    let li = AVMutableVideoCompositionLayerInstruction(assetTrack: s.track)
    li.setTransform(fillTransform(s.natSize, s.pref), at: .zero)
    return li
}

var instructions: [AVMutableVideoCompositionInstruction] = []
for (i, s) in segs.enumerated() {
    let hasPrev = i > 0, hasNext = i < segs.count - 1
    let sEnd = CMTimeAdd(s.start, s.dur)
    let nextStart = hasNext ? segs[i+1].start : sEnd
    let soloStart = hasPrev ? CMTimeAdd(s.start, xfadeT) : s.start

    // solo region (single clip at full opacity)
    if CMTimeCompare(nextStart, soloStart) > 0 {
        let inst = AVMutableVideoCompositionInstruction()
        inst.timeRange = CMTimeRange(start: soloStart, end: nextStart)
        inst.layerInstructions = [layerInstr(s)]
        instructions.append(inst)
    }
    // crossfade region with next clip (outgoing fades out over incoming)
    if hasNext {
        let inst = AVMutableVideoCompositionInstruction()
        let ov = CMTimeRange(start: nextStart, end: sEnd)
        inst.timeRange = ov
        let outL = layerInstr(s)
        outL.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: ov)
        let inL = layerInstr(segs[i+1])
        inst.layerInstructions = [outL, inL]   // outgoing on top, fading to reveal incoming
        instructions.append(inst)
    }
}

let vc = AVMutableVideoComposition()
vc.frameDuration = CMTime(value: 1, timescale: fps)
vc.renderSize = CGSize(width: W, height: H)
vc.instructions = instructions

// Render the composition via reader/writer at a controlled web bitrate (export presets don't cap size).
let bitrate = Int(Double(W * H) * 3.9)   // ~3.6 Mbps at 720p
try? FileManager.default.removeItem(atPath: outPath)
guard let reader = try? AVAssetReader(asset: comp) else { fputs("no reader\n", stderr); exit(5) }
let readerOut = AVAssetReaderVideoCompositionOutput(videoTracks: comp.tracks(withMediaType: .video),
    videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
readerOut.videoComposition = vc
reader.add(readerOut)

let writer = try! AVAssetWriter(outputURL: URL(fileURLWithPath: outPath), fileType: .mp4)
let wset: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: 60
    ]
]
let wInput = AVAssetWriterInput(mediaType: .video, outputSettings: wset)
wInput.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: wInput, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
    kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H
])
writer.add(wInput)
writer.startWriting(); reader.startReading(); writer.startSession(atSourceTime: .zero)

let q = DispatchQueue(label: "asm")
let sem = DispatchSemaphore(value: 0)
wInput.requestMediaDataWhenReady(on: q) {
    while wInput.isReadyForMoreMediaData {
        guard reader.status == .reading, let sb = readerOut.copyNextSampleBuffer() else {
            wInput.markAsFinished(); writer.finishWriting { sem.signal() }; return
        }
        if let pb = CMSampleBufferGetImageBuffer(sb) {
            adaptor.append(pb, withPresentationTime: CMSampleBufferGetPresentationTimeStamp(sb))
        }
    }
}
sem.wait()
if writer.status == .completed {
    print("wrote \(outPath) \(W)x\(H) dur=\(String(format: "%.1f", CMTimeGetSeconds(totalDur)))s clips=\(segs.count)")
} else {
    fputs("write failed: \(String(describing: writer.error)) reader=\(String(describing: reader.error))\n", stderr); exit(6)
}
