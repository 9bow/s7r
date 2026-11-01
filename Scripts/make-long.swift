import AVFoundation
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = try AVAudioFile(forReading: root.appendingPathComponent(".validation/media/English sample.aiff"))
let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: AVAudioFrameCount(source.length))!
try source.read(into: buffer)
let output = try AVAudioFile(forWriting: root.appendingPathComponent(".validation/long-30min.caf"), settings: source.processingFormat.settings)
let silence = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: AVAudioFrameCount(3 * source.processingFormat.sampleRate))!
silence.frameLength = silence.frameCapacity
memset(silence.floatChannelData![0], 0, Int(silence.frameLength) * 4)
try output.write(from: silence)
silence.frameLength = AVAudioFrameCount(6 * source.processingFormat.sampleRate) - buffer.frameLength
for _ in 0..<300 { try output.write(from: buffer); try output.write(from: silence) }
print("1803 seconds, 300 repeats, original text and voice from the English fixture. Speech begins at 3 + 6n seconds.")
