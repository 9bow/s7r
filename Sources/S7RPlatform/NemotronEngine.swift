@preconcurrency import AVFoundation
import Foundation
import MLXAudioSTT
import S7RCore

public actor NemotronEngine {
    private var model: NemotronASRModel?
    private var loadedRoot: String?
    public init() {}
    public func transcribe(_ media: DecodedMedia, settings: Settings, progress: @escaping @Sendable (Double) -> Void) async throws -> [Segment] {
        let root = URL(fileURLWithPath: settings.modelDirectory).standardizedFileURL
        try ModelStore.require("nemotron", root: root)
        guard let source = settings.source else { throw S7RError("Nemotron requires an explicit source language in this version.") }
        if model == nil || loadedRoot != root.path {
            model = try NemotronASRModel.fromDirectory(root.appendingPathComponent("nemotron-0.6b"))
            loadedRoot = root.path
        }
        guard let model else { throw S7RError("Nemotron did not load.") }
        let language = ["ko": "ko-KR", "en": "en-US", "ja": "ja-JP", "zh": "zh-CN"][source.rawValue]!
        let session = model.makeStreamSession(language: language, chunkMs: 1120)
        let file = try AVAudioFile(forReading: media.audio)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 16_000)!
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer)
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
            session.step(samples)
            progress(Double(file.framePosition) / Double(max(1, file.length)))
        }
        try Task.checkCancellation()
        session.finish()
        try Task.checkCancellation()
        return try session.segments.map { item in
            guard let start = item["start"] as? Double, let end = item["end"] as? Double, let text = item["text"] as? String else { throw S7RError("Nemotron returned an invalid timed segment.") }
            return Segment(id: "", start: start, end: end, source: text)
        }
    }
}
