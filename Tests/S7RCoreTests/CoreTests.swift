import Foundation
import Testing
@testable import S7RCore
import S7RPlatform

@Test func captionOrderingAndTimeValidation() throws {
    let segments = [Segment(id: "b", start: 1, end: 3, source: "second"), Segment(id: "a", start: -1, end: 2, source: "first"), Segment(id: "c", start: 3, end: 3, source: "empty")]
    let result = try Captions.normalize(segments, duration: 4)
    #expect(result.map(\.start) == [0, 2])
    #expect(result.map(\.id) == ["s000001", "s000002"])
    #expect(throws: S7RError.self) { try Captions.normalize([Segment(id: "x", start: .nan, end: 1, source: "bad")], duration: 2) }
}
@Test func bilingualEscapingAndFailurePreservation() throws {
    var settings = Settings(); settings.target = .en; settings.display = .bilingual
    let transcript = Transcript(input: "test.wav", duration: 2, language: .ko, target: .en, segments: [Segment(id: "s1", start: 0, end: 1.234, source: "원문 <&>", translation: "Hello"), Segment(id: "s2", start: 1.234, end: 2, source: "실패", translationError: "missing pack")])
    let srt = String(decoding: try Exporter.render(transcript, format: .srt, settings: settings), as: UTF8.self)
    #expect(srt.contains("00:00:01,234"))
    #expect(srt.contains("원문 &lt;&amp;&gt;\nHello"))
    #expect(srt.contains("[Translation failed: s2]"))
    settings.order = .translationFirst
    let reverse = String(decoding: try Exporter.render(transcript, format: .txt, settings: settings), as: UTF8.self)
    #expect(reverse.contains("Hello\n원문 <&>"))
    let json = try JSONDecoder().decode(Transcript.self, from: Exporter.render(transcript, format: .json, settings: settings))
    #expect(json.segments[1].source == "실패")
    #expect(json.segments[1].translation == nil)
    #expect(json.segments[1].translationError == "missing pack")
    let smi = String(decoding: try Exporter.render(transcript, format: .smi, settings: settings), as: UTF8.self)
    #expect(smi.contains("<SYNC Start=2000><P Class=S7R>&nbsp;"))
    #expect(smi.contains("lang: ko"))
    #expect(smi.components(separatedBy: "<SYNC Start=1234>").count == 2)
    #expect(smi.contains("&lt;&amp;&gt;"))
}
@Test func unicodeWrappingPreservesText() {
    for text in ["한국어문장에는공백이없어도줄바꿈합니다", "日本語の字幕を折り返します。", "中文字幕需要正确换行。", "A long English subtitle contains several words."] {
        let lines = Captions.wrap(text, width: 8)
        #expect(lines.allSatisfy { $0.count <= 8 })
        #expect(lines.joined().filter { !$0.isWhitespace } == text.filter { !$0.isWhitespace })
    }
    #expect(Captions.chinese("汉语字幕", script: .traditional) == "漢語字幕")
}
@Test func wordsKeepOriginalFileTime() throws {
    var settings = Settings(); settings.lineLength = 8; settings.maxLines = 1
    let words = [Word(start: 10, end: 11, text: "First."), Word(start: 12, end: 13, text: " Last.")]
    let segments = Captions.split([Segment(id: "", start: 10, end: 13, source: "First. Last.", words: words)], settings: settings)
    #expect(segments.count == 2)
    #expect(segments[0].start == 10)
    #expect(segments[1].end == 13)
}
@Test func collisionAndOverwrite() throws {
    let root = URL(fileURLWithPath: "/private/tmp/s7r-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    var settings = Settings(); settings.outputDirectory = root.path
    let transcript = Transcript(input: "/input/same.wav", duration: 1, language: .en, segments: [Segment(id: "s1", start: 0, end: 1, source: "hello")])
    let first = try Exporter.write(transcript, formats: [.srt, .json], settings: settings)
    let bytes = try Data(contentsOf: URL(fileURLWithPath: first[1]))
    let second = try Exporter.write(transcript, formats: [.srt, .json], settings: settings)
    #expect(first != second)
    #expect(second.allSatisfy { $0.contains("same-2.") })
    #expect(try Data(contentsOf: URL(fileURLWithPath: first[1])) == bytes)
    settings.overwrite = true
    let overwritten = try Exporter.write(transcript, formats: [.srt, .json], settings: settings)
    #expect(overwritten.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath() } == first.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath() })
}
private struct TestProcessor: FileProcessor {
    func process(_ input: URL, settings: Settings, progress: @escaping @Sendable (ProgressEvent) -> Void) async throws -> JobResult {
        if input.lastPathComponent == "bad" { throw S7RError("fixture failure") }
        if input.lastPathComponent == "wait" { try await Task.sleep(for: .seconds(30)) }
        return JobResult(input: input.path, state: .succeeded)
    }
}
@Test func batchIsolatesFailureAndCancellation() async throws {
    let runner = BatchProcessor(processor: TestProcessor())
    let summary = await runner.run(inputs: [URL(fileURLWithPath: "/bad"), URL(fileURLWithPath: "/good")], settings: Settings()) { _ in }
    #expect(summary.succeeded == 1); #expect(summary.failed == 1); #expect(summary.exitCode == 1)
    let task = Task { await runner.run(inputs: [URL(fileURLWithPath: "/wait"), URL(fileURLWithPath: "/later")], settings: Settings()) { _ in } }
    task.cancel()
    let cancelled = await task.value
    #expect(cancelled.jobs.allSatisfy { $0.state == .cancelled })
    #expect(cancelled.exitCode == 130)
}
@Test func directoryRecursionAndDuplicates() throws {
    let root = URL(fileURLWithPath: "/private/tmp/s7r-input-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root.appendingPathComponent("sub"), withIntermediateDirectories: true)
    let first = root.appendingPathComponent("한국어 sample.wav")
    try Data([1]).write(to: first)
    try Data([2]).write(to: root.appendingPathComponent("sub/two.mp4"))
    #expect(try Inputs.expand([root.path, first.path], recursive: false).count == 1)
    #expect(try Inputs.expand([root.path, first.path], recursive: true).count == 2)
}
@Test func missingModelsFailWithoutNetwork() async throws {
    #expect(!ModelStore.installed("whisper", root: URL(fileURLWithPath: "/private/tmp/absent-s7r-model")))
    #expect(throws: S7RError.self) { try ModelStore.require("whisper", root: URL(fileURLWithPath: "/private/tmp/absent-s7r-model")) }
}
@Test func invalidSettings() {
    var settings = Settings(); settings.source = nil
    #expect(throws: S7RError.self) { try settings.validate() }
    settings.asr = .whisper; settings.display = .translated
    #expect(throws: S7RError.self) { try settings.validate() }
}

@Test func bilingualPagesRetainBothLanguages() throws {
    var settings = Settings(); settings.target = .ko; settings.display = .bilingual; settings.lineLength = 8
    let transcript = Transcript(input: "test.wav", duration: 10, language: .en, target: .ko, segments: [Segment(id: "s1", start: 0, end: 10, source: "hello", translation: "이 문장은 원문보다 길어서 여러 자막 페이지로 나누어 표시합니다.")])
    let text = String(decoding: try Exporter.render(transcript, format: .srt, settings: settings), as: UTF8.self)
    let blocks = text.split(separator: "\n\n")
    #expect(blocks.count > 1)
    #expect(blocks.allSatisfy { $0.contains("hello") && $0.split(separator: "\n").count == 4 })
}

@Test func translationRejectsAddedTimeOfDay() {
    #expect(TranslationFidelity.addsDayPeriod(source: "The meeting starts at nine.", translation: "회의는 오전 아홉 시에 시작합니다."))
    #expect(!TranslationFidelity.addsDayPeriod(source: "The meeting starts in the morning.", translation: "회의는 오전에 시작합니다."))
    #expect(!TranslationFidelity.addsDayPeriod(source: "I am ready.", translation: "준비됐습니다."))
    #expect(!TranslationFidelity.addsDayPeriod(source: "기사가 도착했습니다.", translation: "A knight arrived."))
}
@Test func configurationRoundTripKeepsCaptionBytes() throws {
    var settings = Settings(); settings.asr = .nemotron; settings.source = .en; settings.target = .ko; settings.display = .bilingual; settings.formats = [.srt, .smi, .json]
    let restored = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    let transcript = Transcript(input: "fixture.wav", duration: 2, language: .en, target: .ko, segments: [Segment(id: "s1", start: 0, end: 2, source: "hello", translation: "안녕하세요")])
    #expect(settings == restored)
    for format in settings.formats { #expect(try Exporter.render(transcript, format: format, settings: settings) == Exporter.render(transcript, format: format, settings: restored)) }
}
