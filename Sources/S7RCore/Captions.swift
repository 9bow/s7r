import Foundation

public enum Captions {
    public static func chinese(_ text: String, script: ChineseScript) -> String {
        let transform = StringTransform(script == .traditional ? "Hans-Hant" : "Hant-Hans")
        return text.applyingTransform(transform, reverse: false) ?? text
    }
    public static func normalize(_ input: [Segment], duration: Double) throws -> [Segment] {
        var result: [Segment] = []
        var previousEnd = 0.0
        for var segment in input.sorted(by: { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }) {
            guard segment.start.isFinite, segment.end.isFinite else { throw S7RError("Non-finite subtitle timestamp.") }
            segment.source = segment.source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !segment.source.isEmpty else { continue }
            segment.start = max(0, previousEnd, segment.start)
            segment.end = min(duration, segment.end)
            guard segment.end > segment.start else { continue }
            segment.id = String(format: "s%06d", result.count + 1)
            previousEnd = segment.end
            result.append(segment)
        }
        return result
    }
    public static func wrap(_ text: String, width: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        var token = ""
        func appendToken() {
            guard !token.isEmpty else { return }
            if !current.isEmpty && current.count + token.count > width {
                lines.append(current.trimmingCharacters(in: .whitespaces)); current = ""
            }
            for char in token {
                if current.count >= width { lines.append(current.trimmingCharacters(in: .whitespaces)); current = "" }
                if !current.isEmpty || !char.isWhitespace { current.append(char) }
            }
            token = ""
        }
        for char in text {
            if char.isNewline {
                appendToken(); if !current.isEmpty { lines.append(current.trimmingCharacters(in: .whitespaces)); current = "" }
            } else if char.isWhitespace {
                appendToken(); if !current.isEmpty && !current.hasSuffix(" ") { current.append(" ") }
            } else if char.unicodeScalars.contains(where: { (0x2E80...0x9FFF).contains($0.value) || (0xAC00...0xD7AF).contains($0.value) || (0xF900...0xFAFF).contains($0.value) }) {
                appendToken(); token = String(char); appendToken()
            } else { token.append(char) }
        }
        appendToken()
        if !current.isEmpty { lines.append(current.trimmingCharacters(in: .whitespaces)) }
        return lines
    }
    public static func split(_ input: [Segment], settings: Settings) -> [Segment] {
        let budget = settings.lineLength * settings.maxLines
        var output: [Segment] = []
        for segment in input {
            guard let words = segment.words, !words.isEmpty else { output.append(segment); continue }
            var group: [Word] = []
            func emit() {
                guard let first = group.first, let last = group.last else { return }
                output.append(Segment(id: "", start: first.start, end: last.end, source: group.map(\.text).joined(), words: group))
                group = []
            }
            for word in words {
                let previous = group.last
                if !group.isEmpty && (group.map(\.text).joined().count + word.text.count > budget || word.end - group[0].start > 7 || word.start - (previous?.end ?? word.start) > 0.8) { emit() }
                group.append(word)
                if word.text.trimmingCharacters(in: .whitespaces).last.map({ ".!?。！？".contains($0) }) == true { emit() }
            }
            emit()
        }
        return output
    }
}
