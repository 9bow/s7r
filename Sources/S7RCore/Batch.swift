import Foundation

public enum Inputs {
    public static func expand(_ paths: [String], recursive: Bool) throws -> [URL] {
        var seen = Set<String>()
        var results: [URL] = []
        for path in paths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { throw S7RError("Symbolic link inputs are not supported: \(path)") }
            var candidates: [URL] = []
            if values?.isDirectory == true {
                let options: FileManager.DirectoryEnumerationOptions = recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: options) else { throw S7RError("Cannot read directory: \(path)") }
                for case let item as URL in enumerator {
                    let metadata = try item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if metadata.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                    if metadata.isRegularFile == true { candidates.append(item) }
                }
                candidates.sort { $0.path < $1.path }
            } else { candidates = [url] }
            for item in candidates where seen.insert(item.resolvingSymlinksInPath().path).inserted { results.append(item) }
        }
        guard !results.isEmpty else { throw S7RError("No input files found.") }
        return results
    }
}
public struct BatchProcessor: Sendable {
    public let processor: any FileProcessor
    public init(processor: any FileProcessor) { self.processor = processor }
    public func run(inputs: [URL], settings: Settings, progress: @escaping @Sendable (ProgressEvent) -> Void) async -> BatchSummary {
        var jobs: [JobResult] = []
        for input in inputs {
            if Task.isCancelled {
                jobs.append(JobResult(input: input.path, state: .cancelled, error: "Cancelled before processing."))
                progress(ProgressEvent(input.path, .cancelled, 0)); continue
            }
            let start = Date()
            do {
                var result = try await processor.process(input, settings: settings, progress: progress)
                result.seconds = Date().timeIntervalSince(start)
                jobs.append(result)
                progress(ProgressEvent(input.path, result.state, 1, result.error ?? ""))
            } catch {
                let state: JobState = error is CancellationError || Task.isCancelled ? .cancelled : .failed
                let reason = state == .cancelled ? nil : error.localizedDescription
                jobs.append(JobResult(input: input.path, state: state, error: reason, seconds: Date().timeIntervalSince(start)))
                progress(ProgressEvent(input.path, state, 1, reason ?? ""))
            }
        }
        return BatchSummary(jobs: jobs)
    }
}
