@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import S7RCore

public struct DecodedMedia: Sendable {
    public let audio: URL
    public let duration: Double
    public let hasVideo: Bool
    public let workspace: URL
    public func removeTemporaryFiles() { try? FileManager.default.removeItem(at: workspace) }
}
public actor MediaDecoder {
    public init() {}
    public func decode(_ input: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> DecodedMedia {
        guard FileManager.default.fileExists(atPath: input.path) else { throw S7RError("Input does not exist: \(input.path)") }
        let asset = AVURLAsset(url: input)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { throw S7RError("The file has no readable audio track.") }
        let hasVideo = try await !asset.loadTracks(withMediaType: .video).isEmpty
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw S7RError("The file has no finite positive duration.") }
        let workspace = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("s7r-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let audio = workspace.appendingPathComponent("audio.caf")
        do {
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
            let file = try AVAudioFile(forWriting: audio, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ])
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else { throw S7RError("AVFoundation cannot decode this audio track.") }
            reader.add(output)
            guard reader.startReading() else { throw reader.error ?? S7RError("Audio decoding did not start.") }
            defer { reader.cancelReading() }
            var position: Int64 = 0
            var samplesRead: Int64 = 0
            let zero = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_000)!
            zero.frameLength = 16_000
            memset(zero.floatChannelData![0], 0, 16_000 * MemoryLayout<Float>.size)
            while let sample = output.copyNextSampleBuffer() {
                try Task.checkCancellation()
                guard let block = CMSampleBufferGetDataBuffer(sample) else { throw S7RError("Audio decoder returned no PCM data.") }
                let count = CMSampleBufferGetNumSamples(sample)
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                guard timestamp.isFinite else { throw S7RError("Audio decoder returned an invalid timestamp.") }
                let start = Int64((timestamp * 16_000).rounded())
                while position < max(0, start) {
                    try Task.checkCancellation()
                    zero.frameLength = AVAudioFrameCount(min(16_000, max(0, start) - position))
                    try file.write(from: zero); position += Int64(zero.frameLength)
                }
                let skip = Int(max(0, position - start))
                guard count > skip else { continue }
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count - skip)) else { throw S7RError("Cannot allocate a decoder buffer.") }
                buffer.frameLength = AVAudioFrameCount(count - skip)
                let code = CMBlockBufferCopyDataBytes(block, atOffset: skip * 4, dataLength: (count - skip) * 4, destination: buffer.floatChannelData![0])
                guard code == kCMBlockBufferNoErr else { throw S7RError("Cannot read decoded PCM bytes: \(code)") }
                try file.write(from: buffer)
                position += Int64(buffer.frameLength); samplesRead += Int64(buffer.frameLength)
                progress(min(1, Double(position) / 16_000 / duration))
            }
            if reader.status == .failed { throw reader.error ?? S7RError("Audio decoding failed.") }
            try Task.checkCancellation()
            guard samplesRead > 0 else { throw S7RError("The audio track contains no decodable samples.") }
            return DecodedMedia(audio: audio, duration: max(duration, Double(position) / 16_000), hasVideo: hasVideo, workspace: workspace)
        } catch {
            try? FileManager.default.removeItem(at: workspace)
            throw error
        }
    }
}
