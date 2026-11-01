import Foundation
import S7RCore

public actor MediaProcessor: FileProcessor {
    private let decoder = MediaDecoder()
    private let appleSpeech = AppleSpeechEngine()
    private let whisper = WhisperEngine()
    private let nemotron = NemotronEngine()
    private let appleTranslation = AppleTranslator()
    private let qwen = QwenTranslator()
    public init() {}
    public func process(_ input: URL, settings: Settings, progress: @escaping @Sendable (ProgressEvent) -> Void) async throws -> JobResult {
        try settings.validate()
        if settings.asr == .whisper { try ModelStore.require("whisper", root: URL(fileURLWithPath: settings.modelDirectory)) }
        if settings.asr == .nemotron { try ModelStore.require("nemotron", root: URL(fileURLWithPath: settings.modelDirectory)) }
        progress(ProgressEvent(input.path, .inspecting, 0))
        let media = try await decoder.decode(input) { fraction in progress(ProgressEvent(input.path, .decoding, fraction * 0.15)) }
        defer { media.removeTemporaryFiles() }
        try Task.checkCancellation()
        progress(ProgressEvent(input.path, .transcribing, 0.15, "Loading \(settings.asr.rawValue); keyword hints: \(settings.keywords.count)"))
        let transcriptionProgress: @Sendable (Double) -> Void = { fraction in progress(ProgressEvent(input.path, .transcribing, 0.15 + fraction * 0.55)) }
        let source: Language
        let raw: [Segment]
        switch settings.asr {
        case .apple:
            guard let language = settings.source else { throw S7RError("Apple Speech requires a source language.") }
            source = language
            raw = try await appleSpeech.transcribe(media, language: language, keywords: settings.keywords, progress: transcriptionProgress)
        case .nemotron:
            guard let language = settings.source else { throw S7RError("Select a source language for Nemotron.") }
            source = language
            raw = try await nemotron.transcribe(media, settings: settings, progress: transcriptionProgress)
        case .whisper:
            (source, raw) = try await whisper.transcribe(media, settings: settings, progress: transcriptionProgress)
        }
        var segments = try Captions.normalize(Captions.split(raw, settings: settings), duration: media.duration)
        var warnings: [String] = []
        if segments.isEmpty { warnings.append("No speech detected.") }
        if let target = settings.target {
            for index in segments.indices {
                try Task.checkCancellation()
                progress(ProgressEvent(input.path, .translating, 0.7 + Double(index) / Double(max(1, segments.count)) * 0.25, segments[index].id))
                do {
                    if source == target { segments[index].translation = target == .zh ? Captions.chinese(segments[index].source, script: settings.chineseScript) : segments[index].source }
                    else if settings.translator == .apple { segments[index].translation = try await appleTranslation.translate(segments[index].source, from: source, to: target, script: settings.chineseScript) }
                    else { segments[index].translation = try await qwen.translate(segments[index].source, from: source, to: target, settings: settings) }
                } catch is CancellationError { throw CancellationError() }
                catch { segments[index].translationError = error.localizedDescription }
            }
        }
        let failures = segments.filter { $0.translationError != nil }
        if !failures.isEmpty { warnings.append("Translation failed for \(failures.count) segments. Original text is preserved in JSON and source output. Translation-only output is incomplete.") }
        let transcript = Transcript(input: input.path, duration: media.duration, language: source, target: settings.target, segments: segments, warnings: warnings)
        try Task.checkCancellation()
        progress(ProgressEvent(input.path, .exporting, 0.95))
        var formats = settings.formats.isEmpty ? [media.hasVideo ? OutputFormat.srt : .txt] : settings.formats
        if !failures.isEmpty && !formats.contains(.json) { formats.append(.json) }
        let outputs = try Exporter.write(transcript, formats: formats, settings: settings)
        return JobResult(input: input.path, state: failures.isEmpty ? .succeeded : .partial, outputs: outputs, error: failures.isEmpty ? nil : "Translation is incomplete.", warnings: warnings)
    }
}
