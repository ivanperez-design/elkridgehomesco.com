import Foundation
import AVFoundation
import CoreMedia

// Time-compress a video to a target duration (uniform speed-up), re-encoded at a web bitrate.
// args: in.mp4 out.mp4 W H targetSeconds
let a = CommandLine.arguments
guard a.count >= 6 else { fputs("usage: speedup in out W H targetSeconds\n", stderr); exit(2) }
let inPath = a[1], outPath = a[2]
let W = Int(a[3])!, H = Int(a[4])!
let target = Double(a[5])!
let fps: Int32 = 30, ts: Int32 = 600

let src = AVURLAsset(url: URL(fileURLWithPath: inPath))
guard let vt = src.tracks(withMediaType: .video).first else { fputs("no video track\n", stderr); exit(3) }
let srcDur = src.duration

let comp = AVMutableComposition()
let track = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try! track.insertTimeRange(CMTimeRange(start: .zero, duration: srcDur), of: vt, at: .zero)
let targetT = CMTime(seconds: target, preferredTimescale: ts)
track.scaleTimeRange(CMTimeRange(start: .zero, duration: srcDur), toDuration: targetT)
track.preferredTransform = vt.preferredTransform

let vc = AVMutableVideoComposition()
vc.frameDuration = CMTime(value: 1, timescale: fps)
vc.renderSize = CGSize(width: W, height: H)
let inst = AVMutableVideoCompositionInstruction()
inst.timeRange = CMTimeRange(start: .zero, duration: targetT)
let li = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
// aspect-fill into WxH
let post0 = CGRect(origin: .zero, size: vt.naturalSize).applying(vt.preferredTransform)
let dispW = abs(post0.width), dispH = abs(post0.height)
let scale = max(Double(W)/Double(dispW), Double(H)/Double(dispH))
var tf = vt.preferredTransform.concatenating(CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
let post = CGRect(origin: .zero, size: vt.naturalSize).applying(tf)
tf = tf.concatenating(CGAffineTransform(translationX: (CGFloat(W)-post.width)/2 - post.minX,
                                        y: (CGFloat(H)-post.height)/2 - post.minY))
li.setTransform(tf, at: .zero)
inst.layerInstructions = [li]
vc.instructions = [inst]

try? FileManager.default.removeItem(atPath: outPath)
guard let reader = try? AVAssetReader(asset: comp) else { fputs("no reader\n", stderr); exit(4) }
let rOut = AVAssetReaderVideoCompositionOutput(videoTracks: comp.tracks(withMediaType: .video),
    videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
rOut.videoComposition = vc
reader.add(rOut)

let writer = try! AVAssetWriter(outputURL: URL(fileURLWithPath: outPath), fileType: .mp4)
let wInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: Int(Double(W*H) * 4.2),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: 60 ]
])
wInput.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: wInput, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
    kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
writer.add(wInput)
writer.startWriting(); reader.startReading(); writer.startSession(atSourceTime: .zero)
let q = DispatchQueue(label: "spd"); let sem = DispatchSemaphore(value: 0)
wInput.requestMediaDataWhenReady(on: q) {
    while wInput.isReadyForMoreMediaData {
        guard reader.status == .reading, let sb = rOut.copyNextSampleBuffer() else {
            wInput.markAsFinished(); writer.finishWriting { sem.signal() }; return
        }
        if let pb = CMSampleBufferGetImageBuffer(sb) {
            adaptor.append(pb, withPresentationTime: CMSampleBufferGetPresentationTimeStamp(sb))
        }
    }
}
sem.wait()
if writer.status == .completed { print("wrote \(outPath) \(W)x\(H) target=\(target)s (from \(String(format:"%.1f",CMTimeGetSeconds(srcDur)))s)") }
else { fputs("failed: \(String(describing: writer.error))\n", stderr); exit(6) }
