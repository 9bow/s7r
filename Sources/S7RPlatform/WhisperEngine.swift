@preconcurrency import AVFoundation
@preconcurrency import WhisperKit
import Foundation
import S7RCore

// This adapter bypasses WhisperKit's network fallback when a tokenizer fails to load.
private final class OfflineTokenizer: WhisperTokenizer {
    let tokenizer: TokenizerWrapper
    let specialTokens: SpecialTokens
    let allLanguageTokens: Set<Int>
    init(directory: URL) async throws {
        let loaded = try await AutoTokenizerWrapper.from(modelFolder: directory)
        tokenizer = loaded
        func token(_ name: String) throws -> Int {
            guard let value = loaded.convertTokenToId(name) else { throw S7RError("Tokenizer is missing \(name). Reinstall Whisper.") }
            return value
        }
        specialTokens = try SpecialTokens(endToken: token("<|endoftext|>"), englishToken: token("<|en|>"), noSpeechToken: token("<|nospeech|>"), noTimestampsToken: token("<|notimestamps|>"), specialTokenBegin: token("<|endoftext|>"), startOfPreviousToken: token("<|startofprev|>"), startOfTranscriptToken: token("<|startoftranscript|>"), timeTokenBegin: token("<|0.00|>"), transcribeToken: token("<|transcribe|>"), translateToken: token("<|translate|>"), whitespaceToken: 220)
        allLanguageTokens = Set(Constants.languages.values.compactMap { loaded.convertTokenToId("<|\($0)|>") })
    }
    func encode(text: String) -> [Int] { tokenizer.encode(text: text, addSpecialTokens: false) }
    func decode(tokens: [Int]) -> String { tokenizer.decode(tokens: tokens) }
    func convertTokenToId(_ token: String) -> Int? { tokenizer.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { tokenizer.convertIdToToken(id) }
    func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        var words: [String] = []
        var groups: [[Int]] = []
        var pending: [Int] = []
        for id in tokenIds {
            pending.append(id)
            let text = decode(tokens: pending)
            if text.contains("\u{fffd}") { continue }
            let asian = text.unicodeScalars.contains { (0x2E80...0x9FFF).contains($0.value) }
            let startsWord = text.first?.isWhitespace == true || id >= specialTokens.specialTokenBegin || asian
            if startsWord || words.isEmpty || (groups.last?.last ?? 0) >= specialTokens.specialTokenBegin {
                words.append(text); groups.append(pending)
            } else { words[words.count - 1] += text; groups[groups.count - 1] += pending }
            pending = []
        }
        if !pending.isEmpty { words.append(decode(tokens: pending)); groups.append(pending) }
        return (words, groups)
    }
}
private final class OfflineWhisper: WhisperKit {
    override func loadTokenizerIfNeeded() async throws {
        guard tokenizer == nil else { return }
        guard let tokenizerFolder else { throw S7RError("A local tokenizer directory is required.") }
        textDecoder.isModelMultilingual = true
        tokenizer = try await OfflineTokenizer(directory: tokenizerFolder)
    }
}
private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.withLock { value = true } }
    var isCancelled: Bool { lock.withLock { value } }
}
public actor WhisperEngine {
    private var engine: OfflineWhisper?
    private var loadedRoot: String?
    public init() {}
    public func transcribe(_ media: DecodedMedia, settings: Settings, progress: @escaping @Sendable (Double) -> Void) async throws -> (Language, [Segment]) {
        let root = URL(fileURLWithPath: settings.modelDirectory).standardizedFileURL
        try ModelStore.require("whisper", root: root)
        if engine == nil || loadedRoot != root.path {
            engine = try await OfflineWhisper(WhisperKitConfig(model: "small", modelFolder: root.appendingPathComponent("whisper-small").path, tokenizerFolder: root.appendingPathComponent("whisper-tokenizer"), verbose: false, logLevel: .none, prewarm: false, load: true, download: false))
            loadedRoot = root.path
        }
        guard let engine else { throw S7RError("Whisper did not load.") }
        let file = try AVAudioFile(forReading: media.audio)
        let sampleRate = file.processingFormat.sampleRate
        let total = file.length
        var offset: AVAudioFramePosition = 0
        var segments: [Segment] = []
        var language = settings.source
        let prompt = settings.keywords.isEmpty ? nil : engine.tokenizer?.encode(text: settings.keywords.joined(separator: ", ")).filter { $0 < 50257 }.suffix(224).map { $0 }
        while offset < total {
            try Task.checkCancellation()
            file.framePosition = offset
            let count = AVAudioFrameCount(min(AVAudioFramePosition(28 * sampleRate), total - offset))
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: count)!
            try file.read(into: buffer, frameCount: count)
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
            let start = Double(offset) / sampleRate
            let last = offset + Int64(count) >= total
            let lower = offset == 0 ? 0 : start + 2
            let upper = last ? media.duration : start + 26
            let energy = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(max(1, samples.count))
            if energy > 0.00000001 {
                let options = DecodingOptions(language: language?.rawValue, temperatureFallbackCount: 2, detectLanguage: language == nil, skipSpecialTokens: true, wordTimestamps: true, promptTokens: prompt, concurrentWorkerCount: 1)
                let cancellation = CancellationFlag()
                let results = try await withTaskCancellationHandler {
                    try await engine.transcribe(audioArray: samples, decodeOptions: options, callback: { _ in !cancellation.isCancelled })
                } onCancel: { cancellation.cancel() }
                try Task.checkCancellation()
                for result in results {
                    if language == nil {
                        guard let detected = Language(rawValue: result.language) else { throw S7RError("Detected language \(result.language) is outside the supported language set. Select the input language manually.") }
                        language = detected
                    }
                    for segment in result.segments where segment.noSpeechProb < 0.8 && !segment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        guard let aligned = segment.words, !aligned.isEmpty else { throw S7RError("Whisper returned text without word timing. Subtitle export requires aligned words.") }
                        let words = aligned.compactMap { word -> Word? in
                            let wordStart = start + Double(word.start)
                            let wordEnd = max(wordStart + 0.001, start + Double(word.end))
                            let center = (wordStart + wordEnd) / 2
                            guard center >= lower, center < upper, wordEnd > wordStart else { return nil }
                            return Word(start: max(0, wordStart), end: min(media.duration, wordEnd), text: word.word)
                        }
                        if let first = words.first, let final = words.last {
                            segments.append(Segment(id: "", start: first.start, end: final.end, source: words.map(\.text).joined(), words: words))
                        }
                    }
                }
            }
            progress(min(1, Double(offset + Int64(count)) / Double(total)))
            if last { break }
            offset += AVAudioFramePosition(24 * sampleRate)
        }
        guard let recognized = language ?? settings.source else { throw S7RError("No speech detected. Automatic language detection could not determine a language. Select a source language manually.") }
        return (recognized, segments)
    }
}
