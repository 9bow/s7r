import AVFoundation
import Foundation
for path in CommandLine.arguments.dropFirst() {
 do {
 let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
 let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 16000)!
 var peak: Float = 0
 var energy = 0.0
 var count = 0
 while file.framePosition < file.length {
  try file.read(into: buffer)
  if let channel = buffer.floatChannelData?[0] { for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channel[i])); energy += Double(channel[i]*channel[i]); count += 1 } }
 }
 print(path, file.processingFormat, "frames", file.length, "peak", peak, "rms", sqrt(energy / Double(max(1,count))))
 } catch { print(error) }
}
