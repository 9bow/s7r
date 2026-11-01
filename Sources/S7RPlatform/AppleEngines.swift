@preconcurrency import AVFoundation
import Foundation
import Speech
import Translation
import S7RCore

public actor AppleSpeechEngine {
    public init() {}
    public static func status(_ language: Language) async -> String {
        guard SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: language.locale) else { return "unsupported" }
        return String(describing: await AssetInventory.status(forModules: [SpeechTranscriber(locale: locale, preset: .timeIndexedProgressiveTranscription)]))
    }
    public static func install(_ language: Language) async throws {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: language.locale) else { throw S7RError("Apple Speech does not support \(language.name) on this device.") }
        let module = SpeechTranscriber(locale: locale, preset: .timeIndexedProgressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) { try await request.downloadAndInstall() }
    }
    public func transcribe(_ media: DecodedMedia, language: Language, keywords: [String], progress: @escaping @Sendable (Double) -> Void) async throws -> [Segment] {
        guard SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: language.locale) else { throw S7RError("Apple Speech is unavailable for \(language.name). Select Whisper explicitly.") }
        let module = SpeechTranscriber(locale: locale, preset: .timeIndexedProgressiveTranscription)
        guard await AssetInventory.status(forModules: [module]) == .installed else { throw S7RError("Apple Speech assets are not installed for \(language.name). Use the GUI Install Speech button or `s7r install-speech --source \(language.rawValue)`. No download started.") }
        let context = AnalysisContext()
        context.contextualStrings[.general] = keywords
        let analyzer = SpeechAnalyzer(modules: [module])
        try await analyzer.setContext(context)
        let file = try AVAudioFile(forReading: media.audio)
        let collector = Task { () throws -> [Segment] in
            var segments: [Segment] = []
            for try await result in module.results {
                try Task.checkCancellation()
                guard result.isFinal else { continue }
                let start = result.range.start.seconds
                let end = result.range.end.seconds
                var words: [Word] = []
                for run in result.text.runs {
                    if let range = run.audioTimeRange {
                        words.append(Word(start: range.start.seconds, end: range.end.seconds, text: String(result.text[run.range].characters)))
                    }
                }
                segments.append(Segment(id: "", start: start, end: end, source: String(result.text.characters), words: words.isEmpty ? nil : words))
                progress(min(1, end / media.duration))
            }
            return segments
        }
        return try await withTaskCancellationHandler {
            do {
                try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
                return try await collector.value
            } catch {
                collector.cancel()
                await analyzer.cancelAndFinishNow()
                throw error
            }
        } onCancel: {
            collector.cancel()
            Task { await analyzer.cancelAndFinishNow() }
        }
    }
}
private final class TranslationSessionBox: @unchecked Sendable {
    let value: TranslationSession
    init(_ value: TranslationSession) { self.value = value }
    func translate(_ text: String) async throws -> String {
        try Task.checkCancellation()
        let (results, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let operation = Task {
            do {
                try Task.checkCancellation()
                continuation.yield(try await value.translate(text).targetText)
                continuation.finish()
            } catch { continuation.finish(throwing: error) }
        }
        return try await withTaskCancellationHandler {
            var iterator = results.makeAsyncIterator()
            guard let result = try await iterator.next() else { throw CancellationError() }
            try Task.checkCancellation()
            return result
        } onCancel: {
            continuation.finish(throwing: CancellationError())
            operation.cancel()
            self.value.cancel()
        }
    }
}
public actor AppleTranslator {
    private var session: TranslationSessionBox?
    private var preparedPair: String?
    public init() {}
    public static func language(_ language: Language, script: ChineseScript) -> Locale.Language {
        Locale.Language(identifier: language == .zh ? (script == .traditional ? "zh-Hant" : "zh-Hans") : language.rawValue)
    }
    public static func status(from source: Language, to target: Language, script: ChineseScript) async -> String {
        if source == target { return "identity" }
        return String(describing: await LanguageAvailability().status(from: language(source, script: script), to: language(target, script: script)))
    }
    public func translate(_ text: String, from source: Language, to target: Language, script: ChineseScript) async throws -> String {
        try Task.checkCancellation()
        if source == target { return target == .zh ? Captions.chinese(text, script: script) : text }
        let sourceLanguage = Self.language(source, script: script)
        let targetLanguage = Self.language(target, script: script)
        let pair = "\(source.rawValue)>\(target.rawValue):\(script.rawValue)"
        if preparedPair != pair {
            let status = await LanguageAvailability().status(from: sourceLanguage, to: targetLanguage)
            guard status == .installed else { throw S7RError("Apple Translation pair \(pair) is \(status). Prepare the language packs in the GUI. No download started.") }
            session = TranslationSessionBox(TranslationSession(installedSource: sourceLanguage, target: targetLanguage))
            preparedPair = pair
        }
        guard let session else { throw S7RError("Apple Translation session is unavailable.") }
        let result: String
        do {
            result = try await session.translate(text)
            try Task.checkCancellation()
        } catch {
            self.session = nil
            preparedPair = nil
            throw error
        }
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw S7RError("Apple Translation returned empty text.") }
        return result
    }
}
