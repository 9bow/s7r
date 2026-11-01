@preconcurrency import AVFoundation
import Foundation
@main struct PlaybackFixture {
 static func main() async throws {
  let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".validation/media")
  let asset=AVURLAsset(url:root.appendingPathComponent("offset video.mp4"))
  let composition=AVMutableComposition()
  let sourceVideo=try await asset.loadTracks(withMediaType:.video)[0]
  let sourceDuration=try await asset.load(.duration)
  let video=composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!
  try video.insertTimeRange(CMTimeRange(start:.zero,duration:sourceDuration),of:sourceVideo,at:.zero)
  for second in 0..<4 {
   try video.insertTimeRange(CMTimeRange(start:sourceDuration-CMTime(seconds:1,preferredTimescale:600),duration:CMTime(seconds:1,preferredTimescale:600)),of:sourceVideo,at:sourceDuration+CMTime(seconds:Double(second),preferredTimescale:600))
  }
  let sourceAudio=try await asset.loadTracks(withMediaType:.audio)[0]
  let audioRange=try await sourceAudio.load(.timeRange)
  try composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!.insertTimeRange(audioRange,of:sourceAudio,at:audioRange.start)
  let output=root.appendingPathComponent("playback demo.mp4")
  if FileManager.default.fileExists(atPath:output.path) { try FileManager.default.removeItem(at:output) }
  let exporter=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality)!
  try await exporter.export(to:output,as:.mp4)
  print("Playback demo: audio starts at 3 seconds, video lasts 12 seconds.")
 }
}
