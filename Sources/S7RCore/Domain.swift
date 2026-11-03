import Foundation

public enum Language: String, Codable, CaseIterable, Sendable {
    case ko, en, ja, zh
    public var name: String { ["ko": "Korean", "en": "English", "ja": "Japanese", "zh": "Chinese (Mandarin)"][rawValue]! }
    public var locale: Locale { Locale(identifier: ["ko": "ko-KR", "en": "en-US", "ja": "ja-JP", "zh": "zh-CN"][rawValue]!) }
}
public enum ChineseScript: String, Codable, CaseIterable, Sendable { case simplified, traditional }
public enum ASREngine: String, Codable, CaseIterable, Sendable { case apple, whisper, nemotron }
public enum TranslationEngine: String, Codable, CaseIterable, Sendable { case apple, qwen }
public enum OutputFormat: String, Codable, CaseIterable, Sendable { case txt, srt, smi, json }
public enum DisplayMode: String, Codable, CaseIterable, Sendable { case source, translated, bilingual }
public enum LanguageOrder: String, Codable, CaseIterable, Sendable { case sourceFirst, translationFirst }

public struct Settings: Codable, Equatable, Sendable {
    public var source: Language? = .ko
    public var target: Language? = nil
    public var chineseScript: ChineseScript = .simplified
    public var asr: ASREngine = .nemotron
    public var translator: TranslationEngine = .apple
    public var formats: [OutputFormat] = []
    public var display: DisplayMode = .source
    public var order: LanguageOrder = .sourceFirst
    public var lineLength = 42
    public var maxLines = 2
    public var recursive = false
    public var overwrite = false
    public var outputDirectory: String = ""
    public var modelDirectory: String = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/s7r").path
    public var keywords: [String] = []
    public init() {}
    public func validate() throws {
        guard (8...120).contains(lineLength), (1...6).contains(maxLines) else { throw S7RError("Line length must be 8...120. Maximum lines must be 1...6.") }
        guard source != nil || asr == .whisper else { throw S7RError("Automatic language detection requires Whisper.") }
        guard display != .bilingual || maxLines >= 2 else { throw S7RError("Bilingual output requires at least two lines.") }
        guard target != nil || display == .source else { throw S7RError("Select a translation target for translated or bilingual output.") }
        guard asr != .nemotron || keywords.isEmpty else { throw S7RError("Nemotron does not support context hints. Select Apple Speech or Whisper for keyword hints.") }
        guard keywords.count <= 100, keywords.joined().count <= 4000 else { throw S7RError("Keywords exceed 100 terms or 4000 characters.") }
    }
    public static func vocabulary(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
public struct S7RError: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
public struct Word: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var text: String
    public init(start: Double, end: Double, text: String) { self.start = start; self.end = end; self.text = text }
}
public struct Segment: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var start: Double
    public var end: Double
    public var source: String
    public var translation: String?
    public var translationError: String?
    public var speakerID: String?
    public var words: [Word]?
    public init(id: String, start: Double, end: Double, source: String, translation: String? = nil, translationError: String? = nil, speakerID: String? = nil, words: [Word]? = nil) {
        self.id = id; self.start = start; self.end = end; self.source = source
        self.translation = translation; self.translationError = translationError; self.speakerID = speakerID; self.words = words
    }
}
public struct Transcript: Codable, Sendable {
    public var schemaVersion = 1
    public var input: String
    public var duration: Double
    public var language: Language
    public var target: Language?
    public var segments: [Segment]
    public var warnings: [String]
    public init(input: String, duration: Double, language: Language, target: Language? = nil, segments: [Segment], warnings: [String] = []) {
        self.input = input; self.duration = duration; self.language = language; self.target = target; self.segments = segments; self.warnings = warnings
    }
}
public enum JobState: String, Codable, Sendable { case queued, inspecting, decoding, transcribing, translating, exporting, succeeded, partial, failed, cancelled }
public struct ProgressEvent: Codable, Sendable {
    public var input: String
    public var state: JobState
    public var fraction: Double
    public var message: String
    public init(_ input: String, _ state: JobState, _ fraction: Double, _ message: String = "") {
        self.input = input; self.state = state; self.fraction = fraction; self.message = message
    }
}
public struct JobResult: Codable, Sendable {
    public var input: String
    public var state: JobState
    public var outputs: [String]
    public var error: String?
    public var warnings: [String]
    public var seconds: Double
    public init(input: String, state: JobState, outputs: [String] = [], error: String? = nil, warnings: [String] = [], seconds: Double = 0) {
        self.input = input; self.state = state; self.outputs = outputs; self.error = error; self.warnings = warnings; self.seconds = seconds
    }
}
public struct BatchSummary: Encodable, Sendable {
    public var jobs: [JobResult]
    public var succeeded: Int { jobs.filter { $0.state == .succeeded }.count }
    public var failed: Int { jobs.filter { $0.state == .failed || $0.state == .partial }.count }
    public var cancelled: Bool { jobs.contains { $0.state == .cancelled } }
    public var exitCode: Int32 { cancelled ? 130 : (failed > 0 ? 1 : 0) }
    private enum CodingKeys: String, CodingKey { case jobs, succeeded, failed, cancelled, cancelledCount, exitCode }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jobs, forKey: .jobs)
        try container.encode(succeeded, forKey: .succeeded)
        try container.encode(failed, forKey: .failed)
        try container.encode(cancelled, forKey: .cancelled)
        try container.encode(jobs.filter { $0.state == .cancelled }.count, forKey: .cancelledCount)
        try container.encode(exitCode, forKey: .exitCode)
    }
}
public protocol FileProcessor: Sendable {
    func process(_ input: URL, settings: Settings, progress: @escaping @Sendable (ProgressEvent) -> Void) async throws -> JobResult
}
