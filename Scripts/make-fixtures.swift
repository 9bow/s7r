@preconcurrency import AVFoundation
import AppKit
import Foundation

@main struct Fixtures {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".validation/media")
        let english = root.appendingPathComponent("English sample.aiff")
        let source = try AVAudioFile(forReading: english)
        let format = source.processingFormat
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        let wav = root.appendingPathComponent("audio sample.wav")
        let output = try AVAudioFile(forWriting: wav, settings: format.settings)
        while source.framePosition < source.length { try source.read(into: buffer); try output.write(from: buffer) }
        let silenceFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let silent = try AVAudioFile(forWriting: root.appendingPathComponent("silence.wav"), settings: silenceFormat.settings)
        let zero = AVAudioPCMBuffer(pcmFormat: silenceFormat, frameCapacity: 16000)!
        zero.frameLength = 16000; memset(zero.floatChannelData![0], 0, 64000)
        for _ in 0..<3 { try silent.write(from: zero) }
        let asset = AVURLAsset(url: english)
        let duration = try await asset.load(.duration)
        if let m4a = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) { try await m4a.export(to: root.appendingPathComponent("audio sample.m4a"), as: .m4a) }
        let videoURL = root.appendingPathComponent("no audio.mov")
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180])
        writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
        for frame in 0..<Int(duration.seconds + 4) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var pixel: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel)
            CVPixelBufferLockBaseAddress(pixel!, [])
            memset(CVPixelBufferGetBaseAddress(pixel!), 90, CVPixelBufferGetBytesPerRow(pixel!) * 180)
            CVPixelBufferUnlockBaseAddress(pixel!, [])
            guard adaptor.append(pixel!, withPresentationTime: CMTime(value: Int64(frame), timescale: 1)) else { throw writer.error! }
        }
        input.markAsFinished(); await writer.finishWriting()
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL)
        let videoTrack = try await videoAsset.loadTracks(withMediaType: .video)[0]
        let movieDuration = CMTime(seconds: ceil(duration.seconds + 3), preferredTimescale: 600)
        try composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!.insertTimeRange(CMTimeRange(start: .zero, duration: movieDuration), of: videoTrack, at: .zero)
        let audioTrack = try await asset.loadTracks(withMediaType: .audio)[0]
        try composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: CMTime(seconds: 3, preferredTimescale: 600))
        for (name, type) in [("offset video.mp4", AVFileType.mp4), ("offset video.mov", AVFileType.mov)] {
            let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
            try await exporter.export(to: root.appendingPathComponent(name), as: type)
        }
        try Data("corrupt media".utf8).write(to: root.appendingPathComponent("broken.mp4"))
        print("Created WAV, M4A, MP4, MOV, silence, and no-audio fixtures. Video audio starts at three seconds.")
    }
}
