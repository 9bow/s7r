import Darwin
import Foundation
import S7RCore
import S7RPlatform

private let usage = """
s7r: local file transcription and subtitles for Apple Silicon, macOS 26+

Usage:
  s7r transcribe [options] FILE_OR_DIRECTORY...
  s7r status [--models PATH]
  s7r install-model whisper|nemotron|qwen --accept-license [--models PATH]
  s7r install-speech --source ko|en|ja|zh
  s7r translate-text --source LANG --target LANG [--translator apple|qwen] TEXT

Options:
  --source ko|en|ja|zh|auto     Input speech language (default: ko)
  --target ko|en|ja|zh|none     Translation target (default: none)
  --chinese simplified|traditional
  --asr apple|whisper|nemotron          ASR engine (default: nemotron), no fallback
  --translator apple|qwen      Translation engine
  --format txt,srt,smi,json    Default: TXT for audio, SRT for video
  --display source|translated|bilingual
  --order sourceFirst|translationFirst
  --line-length 8...120        Characters per line (default: 42)
  --max-lines 1...6            Total lines per cue (default: 2)
  --output PATH               Output directory (default: beside each input file)
  --models PATH               Model directory (default: ~/.cache/s7r)
  --keywords TEXT             Newline-separated context hints
  --keywords-file PATH        UTF-8 context hints, maximum 100 terms
  --recursive | --no-recursive
  --overwrite | --no-overwrite
  --config PATH               Read complete Settings JSON before CLI options
  --save-config PATH          Save the resolved configuration
  --help                      Show this help
  --                          End options, allow paths that start with a dash

stdout: one JSON batch summary. stderr: JSON progress and errors.
Exit codes: 0 success, 1 file/translation failure, 2 invalid arguments,
            70 engine/setup failure, 130 cancelled.
No model or language pack download starts during transcription.
"""
private func stderr(_ text: String) { FileHandle.standardError.write(Data((text + "\n").utf8)) }
private final class ProgressPrinter: @unchecked Sendable {
    private let lock = NSLock()
    private var previous: ProgressEvent?
    func print(_ event: ProgressEvent) {
        lock.lock(); defer { lock.unlock() }
        if let previous, previous.input == event.input, previous.state == event.state, event.fraction - previous.fraction < 0.02, event.message == previous.message { return }
        previous = event
        if let data = try? JSONEncoder().encode(event) { FileHandle.standardError.write(data); FileHandle.standardError.write(Data([10])) }
    }
}
struct Arguments {
    var command = "transcribe"
    var settings = Settings()
    var paths: [String] = []
    var acceptLicense = false
    var saveConfiguration: String?
    var showHelp = false
    init(_ arguments: [String]) throws {
        var args = arguments
        if let first = args.first, ["transcribe", "status", "install-model", "install-speech", "translate-text"].contains(first) { command = args.removeFirst() }
        var options: [(String, String?)] = []
        var index = 0
        while index < args.count {
            let option = args[index]
            index += 1
            switch option {
            case "--": paths += args[index...]; index = args.count
            case "--help", "-h": showHelp = true
            case "--recursive", "--no-recursive", "--overwrite", "--no-overwrite", "--accept-license": options.append((option, nil))
            case "--config", "--save-config", "--source", "--target", "--chinese", "--asr", "--translator", "--display", "--order", "--format", "--line-length", "--max-lines", "--output", "--models", "--keywords", "--keywords-file":
                guard index < args.count else { throw S7RError("\(option) requires a value.") }
                options.append((option, args[index])); index += 1
            default:
                guard !option.hasPrefix("-") else { throw S7RError("Unknown option: \(option)") }
                paths.append(option)
            }
        }
        if showHelp { return }
        if let file = options.last(where: { $0.0 == "--config" })?.1 {
            settings = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: URL(fileURLWithPath: file)))
        }
        var replacedKeywords = false
        for (option, argument) in options {
            func value() throws -> String {
                guard let argument else { throw S7RError("\(option) requires a value.") }
                return argument
            }
            func enumeration<T: RawRepresentable>(_ type: T.Type) throws -> T where T.RawValue == String {
                let raw = try value()
                guard let result = T(rawValue: raw) else { throw S7RError("Invalid \(option): \(raw)") }
                return result
            }
            switch option {
            case "--config": _ = try value()
            case "--save-config": saveConfiguration = try value()
            case "--source":
                let raw = try value()
                if raw == "auto" { settings.source = nil }
                else { guard let language = Language(rawValue: raw) else { throw S7RError("Invalid source language: \(raw)") }; settings.source = language }
            case "--target":
                let raw = try value()
                if raw == "none" { settings.target = nil }
                else { guard let language = Language(rawValue: raw) else { throw S7RError("Invalid target language: \(raw)") }; settings.target = language }
            case "--chinese": settings.chineseScript = try enumeration(ChineseScript.self)
            case "--asr": settings.asr = try enumeration(ASREngine.self)
            case "--translator": settings.translator = try enumeration(TranslationEngine.self)
            case "--display": settings.display = try enumeration(DisplayMode.self)
            case "--order": settings.order = try enumeration(LanguageOrder.self)
            case "--format":
                settings.formats = try value().split(separator: ",").map { raw in
                    guard let format = OutputFormat(rawValue: String(raw)) else { throw S7RError("Invalid output format: \(raw)") }
                    return format
                }
                guard !settings.formats.isEmpty else { throw S7RError("Select at least one format.") }
            case "--line-length": guard let number = Int(try value()) else { throw S7RError("Invalid line length.") }; settings.lineLength = number
            case "--max-lines": guard let number = Int(try value()) else { throw S7RError("Invalid maximum lines.") }; settings.maxLines = number
            case "--output": settings.outputDirectory = try value()
            case "--models": settings.modelDirectory = try value()
            case "--keywords", "--keywords-file":
                if !replacedKeywords { settings.keywords = []; replacedKeywords = true }
                let text = option == "--keywords" ? try value() : try String(contentsOfFile: value(), encoding: .utf8)
                settings.keywords += Settings.vocabulary(text)
            case "--recursive": settings.recursive = true
            case "--no-recursive": settings.recursive = false
            case "--overwrite": settings.overwrite = true
            case "--no-overwrite": settings.overwrite = false
            case "--accept-license": acceptLicense = true
            default: break
            }
        }
        settings.keywords = Settings.vocabulary(settings.keywords.joined(separator: "\n"))
        try settings.validate()
        if command == "transcribe" && paths.isEmpty { throw S7RError("Provide at least one input file or directory.") }
        if command == "install-model" && (!acceptLicense || paths.count != 1) { throw S7RError("Select one model and pass --accept-license.") }
        if command == "translate-text" && (settings.source == nil || settings.target == nil || paths.isEmpty) { throw S7RError("translate-text requires --source, --target, and text.") }
    }
}
@main struct CLI {
    static func main() async {
        let raw = Array(CommandLine.arguments.dropFirst())
        if raw.isEmpty { print(usage); return }
        let arguments: Arguments
        do { arguments = try Arguments(raw) }
        catch { stderr(error.localizedDescription); exit(2) }
        if arguments.showHelp { print(usage); return }
        let command = Task { () -> Int32 in
            do { return try await run(arguments) }
            catch is CancellationError { stderr("Cancelled."); return 130 }
            catch { stderr(error.localizedDescription); return 70 }
        }
        signal(SIGINT, SIG_IGN); signal(SIGTERM, SIG_IGN)
        let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        let terminate = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
        let cancel: @Sendable () -> Void = {
            command.cancel()
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) { stderr("Cancellation deadline reached."); exit(130) }
        }
        interrupt.setEventHandler(handler: cancel); terminate.setEventHandler(handler: cancel)
        interrupt.resume(); terminate.resume()
        let code = await command.value
        interrupt.cancel(); terminate.cancel()
        exit(code)
    }
    static func run(_ args: Arguments) async throws -> Int32 {
        let settings = args.settings
        if let path = args.saveConfiguration {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(settings).write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        let progress = ProgressPrinter()
        switch args.command {
        case "status":
            // A watchdog bounds capability queries when an OS service does not respond.
            let watchdog = DispatchSource.makeTimerSource(queue: .global())
            watchdog.schedule(deadline: .now() + 30)
            watchdog.setEventHandler { stderr("Apple capability query timed out. Run outside a restricted sandbox and retry."); exit(70) }
            watchdog.resume(); defer { watchdog.cancel() }
            var status: [String: String] = [:]
            for language in Language.allCases { status["speech.\(language.rawValue)"] = await AppleSpeechEngine.status(language) }
            for source in Language.allCases {
                for target in Language.allCases where source != target { status["translation.\(source.rawValue)>\(target.rawValue)"] = await AppleTranslator.status(from: source, to: target, script: settings.chineseScript) }
            }
            for model in try ModelStore.catalog {
                status["model.\(model.id)"] = "\(model.name), \(model.revision), \(model.license), \(model.downloadBytes) bytes, \(ModelStore.installed(model.id, root: URL(fileURLWithPath: settings.modelDirectory)) ? "installed" : "missing"), \(URL(fileURLWithPath: settings.modelDirectory).path)"
            }
            try output(status); return 0
        case "install-model":
            guard args.acceptLicense, args.paths.count == 1 else { throw S7RError("Select whisper, nemotron, or qwen and pass --accept-license. Read `s7r status` for model license and download size.") }
            try await ModelStore.install(args.paths[0], root: URL(fileURLWithPath: settings.modelDirectory)) { fraction in progress.print(ProgressEvent(args.paths[0], .decoding, fraction, "Downloading explicitly selected model")) }
            try output(["installed": args.paths[0]]); return 0
        case "install-speech":
            guard let source = settings.source else { throw S7RError("Select a speech language.") }
            try await AppleSpeechEngine.install(source)
            try output(["installedSpeech": source.rawValue]); return 0
        case "translate-text":
            guard let source = settings.source, let target = settings.target, !args.paths.isEmpty else { throw S7RError("translate-text requires --source, --target, and text.") }
            let text = args.paths.joined(separator: " ")
            let result: String
            if settings.translator == .apple { result = try await AppleTranslator().translate(text, from: source, to: target, script: settings.chineseScript) }
            else { result = try await QwenTranslator().translate(text, from: source, to: target, settings: settings) }
            try output(["source": text, "translation": result]); return 0
        default:
            guard !args.paths.isEmpty else { throw S7RError("Provide at least one input file or directory.") }
            let inputs = try Inputs.expand(args.paths, recursive: settings.recursive)
            let summary = await BatchProcessor(processor: MediaProcessor()).run(inputs: inputs, settings: settings) { event in progress.print(event) }
            try output(summary); return summary.exitCode
        }
    }
    static func output<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        FileHandle.standardOutput.write(try encoder.encode(value)); FileHandle.standardOutput.write(Data([10]))
    }
}
