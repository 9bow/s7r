import AppKit
import Foundation
import S7RCore
import S7RPlatform

@MainActor final class AppModel: ObservableObject {
    @Published var settings = Settings()
    @Published var inputs: [URL] = []
    @Published var events: [String: ProgressEvent] = [:]
    @Published var results: [String: JobResult] = [:]
    @Published var selection: String?
    @Published var preview = ""
    @Published var message = ""
    @Published var running = false
    @Published var summary: BatchSummary?
    @Published var installing = false
    @Published var installProgress = 0.0
    @Published var capabilities: [String: String] = [:]
    @Published var keywords = ""
    @Published private(set) var inputFolders: [URL] = []
    private var customOutputDirectory: String
    private var task: Task<Void, Never>?
    private var installation: Task<Void, Never>?
    private let processor = MediaProcessor()
    init() {
        let base = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL.deletingLastPathComponent() : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        customOutputDirectory = base.appendingPathComponent("Output").path
    }
    var saveBesideInput: Bool {
        get { settings.outputDirectory.isEmpty }
        set {
            if newValue {
                if !settings.outputDirectory.isEmpty { customOutputDirectory = settings.outputDirectory }
                settings.outputDirectory = ""
            } else { settings.outputDirectory = customOutputDirectory }
        }
    }
    func add(_ urls: [URL]) {
        guard !running else { return }
        do {
            let expanded = try Inputs.expand(urls.map(\.path), recursive: settings.recursive, allowEmpty: true)
            for url in urls {
                let folder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? url : url.deletingLastPathComponent()
                let normalized = folder.standardizedFileURL
                if !inputFolders.contains(where: { $0.path == normalized.path }) { inputFolders.append(normalized) }
            }
            var seen = Set(inputs.map(\.path))
            inputs += expanded.filter { seen.insert($0.path).inserted }
        } catch { message = error.localizedDescription }
    }
    func refreshInputs() {
        guard !running, !inputFolders.isEmpty else { return }
        do {
            let folders = inputFolders.filter {
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDirectory) && isDirectory.boolValue
            }
            inputs = try Inputs.expand(folders.map(\.path), recursive: settings.recursive, allowEmpty: true)
            let paths = Set(inputs.map(\.path))
            results = results.filter { paths.contains($0.key) }
            events = events.filter { paths.contains($0.key) }
            summary = nil
            if let selection, !paths.contains(selection) { self.selection = nil; preview = "" }
            message = ""
        } catch { message = error.localizedDescription }
    }
    func clearInputs() {
        inputs = []; inputFolders = []; results = [:]; events = [:]
        selection = nil; preview = ""; summary = nil
    }
    func chooseInput() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = true; panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { add(panel.urls) }
    }
    func chooseDirectory(models: Bool) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            if models { settings.modelDirectory = url.path } else { settings.outputDirectory = url.path }
        }
    }
    func importKeywords() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do { keywords = try String(contentsOf: url, encoding: .utf8) }
            catch { message = error.localizedDescription }
        }
    }
    func start() {
        guard !running, !inputs.isEmpty else { return }
        var configuration = settings
        configuration.keywords = configuration.asr == .nemotron ? [] : Settings.vocabulary(keywords)
        do { try configuration.validate() }
        catch { message = error.localizedDescription; return }
        running = true; message = ""; results = [:]; summary = nil
        for input in inputs { events[input.path] = ProgressEvent(input.path, .queued, 0) }
        let files = inputs
        task = Task { [self] in
            let summary = await BatchProcessor(processor: processor).run(inputs: files, settings: configuration) { event in
                Task { @MainActor [weak self] in self?.events[event.input] = event }
            }
            for result in summary.jobs { results[result.input] = result }
            running = false
            self.summary = summary
            if let selection { showPreview(selection) }
        }
    }
    func cancel() { task?.cancel() }
    func showPreview(_ path: String) {
        selection = path
        guard let result = results[path] else { preview = ""; return }
        let preferred = result.outputs.first(where: { $0.hasSuffix(".srt") || $0.hasSuffix(".txt") || $0.hasSuffix(".smi") }) ?? result.outputs.first
        if let preferred { preview = (try? String(contentsOfFile: preferred, encoding: .utf8)) ?? "" }
        else { preview = result.error ?? "" }
    }
    func saveSettings() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "s7r-settings.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                var resolved = settings; resolved.keywords = resolved.asr == .nemotron ? [] : Settings.vocabulary(keywords)
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(resolved).write(to: url, options: .atomic)
            } catch { message = error.localizedDescription }
        }
    }
    func loadSettings() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let resolved = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: url))
                try resolved.validate(); settings = resolved; keywords = resolved.keywords.joined(separator: "\n")
            } catch { message = error.localizedDescription }
        }
    }
    func refreshCapabilities() {
        Task {
            for language in Language.allCases { capabilities["speech.\(language.rawValue)"] = await AppleSpeechEngine.status(language) }
            if let source = settings.source, let target = settings.target { capabilities["translation"] = await AppleTranslator.status(from: source, to: target, script: settings.chineseScript) }
        }
    }
    func installModel(_ id: String) {
        guard !installing else { return }
        installing = true; installProgress = 0; message = ""
        let root = URL(fileURLWithPath: settings.modelDirectory)
        installation = Task { [self] in
            do {
                try await ModelStore.install(id, root: root) { fraction in Task { @MainActor [weak self] in self?.installProgress = fraction } }
                message = "Installed: \(id)"
            } catch { message = error.localizedDescription }
            installing = false
        }
    }
    func installSpeech() {
        guard let source = settings.source, !installing else { return }
        installing = true
        installation = Task { [self] in
            do { try await AppleSpeechEngine.install(source); refreshCapabilities() }
            catch { message = error.localizedDescription }
            installing = false
        }
    }
    func cancelInstallation() { installation?.cancel() }
    var outputFolder: URL? {
        if !saveBesideInput { return URL(fileURLWithPath: settings.outputDirectory) }
        let input = selection.flatMap { selected in inputs.first { $0.path == selected } } ?? inputs.first
        return input?.deletingLastPathComponent()
    }
    func openOutput() {
        if let outputFolder { NSWorkspace.shared.open(outputFolder) }
    }
}
