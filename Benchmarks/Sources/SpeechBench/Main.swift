@preconcurrency import AVFoundation
import Foundation
import MLX
import MLXAudioCore
import MLXAudioSTT

@main struct SpeechBench {
    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 3 else { throw NSError(domain: "SpeechBench", code: 2, userInfo: [NSLocalizedDescriptionKey: "Usage: SpeechBench nemotron|qwen MODEL_ROOT LANGUAGE:FILE ..."]) }
        let engine = args[0]
        let root = URL(fileURLWithPath: args[1])
        let loadStart = Date()
        var nemotron: NemotronASRModel?
        var qwen: Qwen3ASRModel?
        var aligner: Qwen3ForcedAlignerModel?
        if engine == "nemotron" { nemotron = try NemotronASRModel.fromDirectory(root.appendingPathComponent("nemotron-0.6b")) }
        else {
            qwen = try await Qwen3ASRModel.fromModelDirectory(root.appendingPathComponent("qwen-asr-1.7b"))
            aligner = try await Qwen3ForcedAlignerModel.fromModelDirectory(root.appendingPathComponent("qwen-aligner-0.6b"))
        }
        let loadSeconds = Date().timeIntervalSince(loadStart)
        var records: [[String: Any]] = []
        for item in args.dropFirst(2) {
            let parts = item.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { throw NSError(domain: "SpeechBench", code: 2) }
            let language = parts[0]
            let name = ["en": "English", "ko": "Korean", "ja": "Japanese", "zh": "Chinese"][language]!
            let audioURL = URL(fileURLWithPath: parts[1])
            let (_, audio) = try loadAudioArray(from: audioURL, sampleRate: 16000)
            let start = Date()
            let text: String
            let segments: [[String: Any]]
            if let nemotron {
                let tag = ["en": "en-US", "ko": "ko-KR", "ja": "ja-JP", "zh": "zh-CN"][language]!
                let result = nemotron.generate(audio: audio, generationParameters: .init(language: tag))
                text = result.text; segments = result.segments ?? []
            } else {
                let result = qwen!.generate(audio: audio, maxTokens: 512, language: name)
                text = result.text
                let aligned = aligner!.generate(audio: audio, text: text, language: name)
                segments = aligned.items.map { ["text": $0.text, "start": $0.startTime, "end": $0.endTime] }
            }
            records.append(["language": language, "input": audioURL.path, "text": text, "segments": segments, "seconds": Date().timeIntervalSince(start), "peakMLXBytes": Memory.peakMemory])
            FileHandle.standardError.write(Data("Finished \(engine) \(language)\n".utf8))
        }
        let data = try JSONSerialization.data(withJSONObject: ["engine": engine, "loadSeconds": loadSeconds, "records": records], options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10]))
    }
}
