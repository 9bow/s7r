@preconcurrency import AVFoundation
import AppKit
import Foundation
@main struct TimedPlayback {
 static func main() async throws {
  let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".validation/media")
  let silent=root.appendingPathComponent("timed silent.mov")
  let output=root.appendingPathComponent("timed playback.mp4")
  for file in [silent,output] where FileManager.default.fileExists(atPath:file.path) { try FileManager.default.removeItem(at:file) }
  let writer=try AVAssetWriter(outputURL:silent,fileType:.mov)
  let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:320,AVVideoHeightKey:180])
  let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:320,kCVPixelBufferHeightKey as String:180])
  writer.add(input);writer.startWriting();writer.startSession(atSourceTime:.zero)
  for frame in 0..<130 {
   while !input.isReadyForMoreMediaData { try await Task.sleep(for:.milliseconds(2)) }
   var pixel:CVPixelBuffer?
   CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&pixel)
   CVPixelBufferLockBaseAddress(pixel!,[])
   let context=CGContext(data:CVPixelBufferGetBaseAddress(pixel!),width:320,height:180,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel!),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue|CGBitmapInfo.byteOrder32Big.rawValue)!
   context.setFillColor(NSColor.darkGray.cgColor);context.fill(CGRect(x:0,y:0,width:320,height:180))
   NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:false)
   NSAttributedString(string:String(format:"time %.1f s",Double(frame)/10),attributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:20,weight:.medium),.foregroundColor:NSColor.white]).draw(at:NSPoint(x:12,y:145))
   NSGraphicsContext.restoreGraphicsState();CVPixelBufferUnlockBaseAddress(pixel!,[])
   guard adaptor.append(pixel!,withPresentationTime:CMTime(value:Int64(frame),timescale:10)) else { throw writer.error! }
  }
  input.markAsFinished();await writer.finishWriting()
  let composition=AVMutableComposition()
  let videoAsset=AVURLAsset(url:silent);let sourceVideo=try await videoAsset.loadTracks(withMediaType:.video)[0]
  try composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!.insertTimeRange(CMTimeRange(start:.zero,duration:CMTime(seconds:13,preferredTimescale:600)),of:sourceVideo,at:.zero)
  let audioAsset=AVURLAsset(url:root.appendingPathComponent("English sample.aiff"));let audio=try await audioAsset.loadTracks(withMediaType:.audio)[0];let duration=try await audioAsset.load(.duration)
  try composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!.insertTimeRange(CMTimeRange(start:.zero,duration:duration),of:audio,at:CMTime(seconds:3,preferredTimescale:600))
  try await AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality)!.export(to:output,as:.mp4)
 }
}
