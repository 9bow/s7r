import Foundation

public enum Exporter {
    private struct Cue { var start: Double; var end: Double; var lines: [String] }
    public static func html(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    public static func timestamp(_ time: Double) -> String {
        let ms = Int((max(0, time) * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, ms / 60_000 % 60, ms / 1000 % 60, ms % 1000)
    }
    private static func cues(_ transcript: Transcript, _ settings: Settings) -> [Cue] {
        var cues: [Cue] = []
        for segment in transcript.segments {
            let source = transcript.language == .zh ? Captions.chinese(segment.source, script: settings.chineseScript) : segment.source
            let translation = segment.translation.map { transcript.target == .zh ? Captions.chinese($0, script: settings.chineseScript) : $0 }
            let translated = translation ?? "[Translation failed: \(segment.id)]"
            let content: [String]
            switch settings.display {
            case .source: content = [source]
            case .translated: content = [translated]
            case .bilingual: content = settings.order == .sourceFirst ? [source, translated] : [translated, source]
            }
            let linesPerLanguage = max(1, settings.maxLines / content.count)
            let wrapped = content.map { Captions.wrap($0, width: settings.lineLength) }
            let pages = max(1, wrapped.map { Int(ceil(Double($0.count) / Double(linesPerLanguage))) }.max() ?? 1)
            for page in 0..<pages {
                var lines: [String] = []
                for languageLines in wrapped {
                    if languageLines.count < pages {
                        if !languageLines.isEmpty { lines.append(languageLines[min(languageLines.count - 1, page * languageLines.count / pages)]) }
                    } else {
                        let lower = page * languageLines.count / pages
                        let upper = (page + 1) * languageLines.count / pages
                        lines += languageLines[lower..<upper]
                    }
                }
                if let speaker = segment.speakerID, !lines.isEmpty { lines[0] = "[\(speaker)] " + lines[0] }
                let interval = (segment.end - segment.start) / Double(pages)
                cues.append(Cue(start: segment.start + Double(page) * interval, end: segment.start + Double(page + 1) * interval, lines: lines))
            }
        }
        return cues
    }
    public static func render(_ transcript: Transcript, format: OutputFormat, settings: Settings) throws -> Data {
        if format == .json {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(transcript)
        }
        let cues = cues(transcript, settings)
        if format == .srt || format == .smi {
            for cue in cues {
                guard (cue.end * 1000).rounded() > (cue.start * 1000).rounded() else {
                    throw S7RError("A subtitle page is shorter than one millisecond after rounding. Increase the line length or maximum lines, or export TXT or JSON.")
                }
            }
        }
        let text: String
        switch format {
        case .txt:
            text = cues.map { $0.lines.joined(separator: "\n") }.joined(separator: "\n\n") + "\n"
        case .srt:
            text = cues.enumerated().map { index, cue in
                "\(index + 1)\n\(timestamp(cue.start)) --> \(timestamp(cue.end))\n\(cue.lines.map(html).joined(separator: "\n"))\n"
            }.joined(separator: "\n")
        case .smi:
            let language = settings.display == .translated ? transcript.target ?? transcript.language : transcript.language
            let tag = language == .zh ? (settings.chineseScript == .traditional ? "zh-TW" : "zh-CN") : language.rawValue
            var body = ""
            for (index, cue) in cues.enumerated() {
                body += "<SYNC Start=\(Int((cue.start * 1000).rounded()))><P Class=S7R>\(cue.lines.map(html).joined(separator: "<br>"))</P>\n"
                let end = Int((cue.end * 1000).rounded())
                if index == cues.count - 1 || end < Int((cues[index + 1].start * 1000).rounded()) {
                    body += "<SYNC Start=\(end)><P Class=S7R>&nbsp;</P>\n"
                }
            }
            text = "<SAMI>\n<HEAD>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=utf-8\">\n<STYLE TYPE=\"text/css\">\n<!--\nP { font-family: sans-serif; text-align: center; }\n.S7R { Name: \(tag); lang: \(tag); SAMIType: CC; }\n-->\n</STYLE>\n</HEAD>\n<BODY>\n\(body)</BODY>\n</SAMI>\n"
        case .json: fatalError("JSON handled above")
        }
        return Data(text.utf8)
    }
    public static func write(_ transcript: Transcript, formats: [OutputFormat], settings: Settings) throws -> [String] {
        let directory = settings.outputDirectory.isEmpty
            ? URL(fileURLWithPath: transcript.input).deletingLastPathComponent().standardizedFileURL
            : URL(fileURLWithPath: settings.outputDirectory).standardizedFileURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stem = URL(fileURLWithPath: transcript.input).deletingPathExtension().lastPathComponent
        let formats = Array(Set(formats)).sorted { $0.rawValue < $1.rawValue }
        let rendered = try formats.map { try render(transcript, format: $0, settings: settings) }
        for suffix in 0..<100_000 {
            let basename = suffix == 0 ? stem : "\(stem)-\(suffix + 1)"
            let paths = formats.map { directory.appendingPathComponent(basename).appendingPathExtension($0.rawValue) }
            guard !paths.contains(where: { $0.resolvingSymlinksInPath().path == URL(fileURLWithPath: transcript.input).resolvingSymlinksInPath().path }) else { continue }
            if !settings.overwrite && paths.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) { continue }
            var written: [URL] = []
            do {
                for (index, path) in paths.enumerated() {
                    try Task.checkCancellation()
                    if settings.overwrite { try rendered[index].write(to: path, options: .atomic) }
                    else { try rendered[index].write(to: path, options: .withoutOverwriting) }
                    written.append(path)
                }
                return paths.map(\.path)
            } catch {
                if !settings.overwrite { for path in written { try? FileManager.default.removeItem(at: path) } }
                if (error as NSError).code == NSFileWriteFileExistsError && !settings.overwrite { continue }
                throw error
            }
        }
        throw S7RError("Cannot reserve an output filename.")
    }
}
