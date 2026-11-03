import SwiftUI
import Translation
import S7RCore
import S7RPlatform

@main struct S7RApp: App {
    @StateObject private var model = AppModel()
    @State private var uiLanguage = "ko"
    var body: some Scene {
        WindowGroup {
            ContentView(model: model, uiLanguage: $uiLanguage)
                .environment(\.locale, Locale(identifier: uiLanguage))
                .frame(minWidth: 1060, minHeight: 720)
        }
    }
}
private struct LabelText: View {
    let key: String
    init(_ key: String) { self.key = key }
    var body: some View { Text(LocalizedStringKey(key), bundle: .module) }
}
private final class PackSessionBox: @unchecked Sendable {
    let value: TranslationSession
    init(_ value: TranslationSession) { self.value = value }
    func prepare() async throws { try await value.prepareTranslation() }
}
struct ContentView: View {
    @ObservedObject var model: AppModel
    @Binding var uiLanguage: String
    @State private var packConfiguration: TranslationSession.Configuration?
    @State private var installChoice: String?
    private var sourceBinding: Binding<String> {
        Binding(get: { model.settings.source?.rawValue ?? "auto" }, set: { model.settings.source = Language(rawValue: $0) })
    }
    private var targetBinding: Binding<String> {
        Binding(get: { model.settings.target?.rawValue ?? "none" }, set: { model.settings.target = Language(rawValue: $0) })
    }
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("s7r").font(.largeTitle.bold())
                    Spacer()
                    Picker("", selection: $uiLanguage) {
                        Text("한국어").tag("ko"); Text("English").tag("en"); Text("日本語").tag("ja"); Text("中文").tag("zh-Hans")
                    }.labelsHidden().frame(width: 110)
                }
                LabelText("privacy.local").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button { model.chooseInput() } label: { LabelText("action.add") }.accessibilityIdentifier("add-input")
                    Button { model.clearInputs() } label: { LabelText("action.clear") }
                    Button { model.refreshInputs() } label: {
                        Label { LabelText("action.refreshInputs") } icon: { Image(systemName: "arrow.clockwise") }
                    }.labelStyle(.iconOnly)
                        .help(Text("action.refreshInputs", bundle: .module))
                        .disabled(model.inputFolders.isEmpty)
                        .accessibilityIdentifier("refresh-inputs")
                }.disabled(model.running)
                Toggle(isOn: $model.settings.recursive) { LabelText("input.recursive") }.disabled(model.running)
                List(selection: $model.selection) {
                    ForEach(model.inputs, id: \.path) { url in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent).lineLimit(1).help(url.path)
                            if let event = model.events[url.path] {
                                HStack {
                                    LabelText("state.\(event.state.rawValue)"); Spacer()
                                    if event.state != .failed && event.state != .cancelled { Text(event.fraction, format: .percent.precision(.fractionLength(0))) }
                                }.font(.caption)
                                if event.state != .failed && event.state != .cancelled { ProgressView(value: event.fraction) }
                                if !event.message.isEmpty { Text(event.message).font(.caption2).foregroundStyle(event.state == .failed ? .red : .secondary).lineLimit(3) }
                            }
                        }.padding(.vertical, 4).tag(url.path)
                    }
                }.overlay {
                    if model.inputs.isEmpty { LabelText("input.drop").foregroundStyle(.secondary).allowsHitTesting(false) }
                }
                HStack {
                    Button { model.start() } label: { LabelText("action.start") }.buttonStyle(.borderedProminent).disabled(model.running || model.inputs.isEmpty || model.installing).accessibilityIdentifier("start")
                    Button { model.cancel() } label: { LabelText("action.cancel") }.disabled(!model.running).accessibilityIdentifier("cancel")
                    Spacer()
                    Button { model.openOutput() } label: { LabelText("action.openOutput") }.disabled(model.outputFolder == nil)
                }
                if let summary = model.summary {
                    HStack {
                        LabelText("summary.success"); Text("\(summary.succeeded)")
                        LabelText("summary.failed"); Text("\(summary.failed)")
                        LabelText("summary.cancelled"); Text("\(summary.jobs.filter { $0.state == .cancelled }.count)")
                    }.font(.caption)
                }
                Text(model.message).font(.caption).textSelection(.enabled).frame(minHeight: model.message.isEmpty ? 0 : 28)
                LabelText("preview.title").font(.headline)
                ScrollView {
                    Text(model.preview).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }.frame(minHeight: 130, maxHeight: 220).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
            }.padding(20).frame(minWidth: 450)
            ScrollView {
                Form {
                    Section {
                        Picker(selection: $model.settings.asr) { Text("Apple Speech").tag(ASREngine.apple); Text("Whisper small (Core ML)").tag(ASREngine.whisper); Text("Nemotron 3.5 (MLX)").tag(ASREngine.nemotron) } label: { LabelText("engine.asr") }
                        Picker(selection: sourceBinding) {
                            ForEach(Language.allCases, id: \.self) { language in LabelText("language.\(language.rawValue)").tag(language.rawValue) }
                            if model.settings.asr == .whisper { LabelText("language.auto").tag("auto") }
                        } label: { LabelText("language.source") }
                        Picker(selection: targetBinding) {
                            LabelText("translation.off").tag("none")
                            ForEach(Language.allCases, id: \.self) { language in LabelText("language.\(language.rawValue)").tag(language.rawValue) }
                        } label: { LabelText("language.target") }
                        Picker(selection: $model.settings.chineseScript) {
                            LabelText("chinese.simplified").tag(ChineseScript.simplified)
                            LabelText("chinese.traditional").tag(ChineseScript.traditional)
                        } label: { LabelText("chinese.script") }
                        Picker(selection: $model.settings.translator) { Text("Apple Translation").tag(TranslationEngine.apple); Text("Qwen3-4B (MLX)").tag(TranslationEngine.qwen) } label: { LabelText("engine.translation") }.disabled(model.settings.target == nil)
                        LabelText("engine.hardware").font(.caption).foregroundStyle(.secondary)
                    } header: { LabelText("section.language") }
                    Section {
                        Picker(selection: $model.settings.display) {
                            LabelText("display.source").tag(DisplayMode.source)
                            LabelText("display.translated").tag(DisplayMode.translated)
                            LabelText("display.bilingual").tag(DisplayMode.bilingual)
                        } label: { LabelText("output.display") }
                        Picker(selection: $model.settings.order) {
                            LabelText("order.sourceFirst").tag(LanguageOrder.sourceFirst)
                            LabelText("order.translationFirst").tag(LanguageOrder.translationFirst)
                        } label: { LabelText("output.order") }.disabled(model.settings.display != .bilingual)
                        HStack {
                            LabelText("output.formats")
                            ForEach(OutputFormat.allCases, id: \.self) { format in
                                Toggle(format.rawValue.uppercased(), isOn: Binding(get: { model.settings.formats.contains(format) }, set: { selected in
                                    model.settings.formats.removeAll { $0 == format }; if selected { model.settings.formats.append(format) }
                                })).toggleStyle(.checkbox)
                            }
                        }
                        LabelText("output.default").font(.caption).foregroundStyle(.secondary)
                        Stepper(value: $model.settings.lineLength, in: 8...120) { HStack { LabelText("output.lineLength"); Spacer(); Text("\(model.settings.lineLength)") } }
                        Stepper(value: $model.settings.maxLines, in: 1...6) { HStack { LabelText("output.maxLines"); Spacer(); Text("\(model.settings.maxLines)") } }
                        Toggle(isOn: $model.settings.overwrite) { LabelText("output.overwrite") }
                        Toggle(isOn: $model.saveBesideInput) { LabelText("output.besideInput") }
                            .toggleStyle(.checkbox).accessibilityIdentifier("save-beside-input")
                        if !model.saveBesideInput {
                            Button { model.chooseDirectory(models: false) } label: { LabelText("action.outputFolder") }
                            Text(model.settings.outputDirectory).font(.caption).textSelection(.enabled)
                        }
                    } header: { LabelText("section.output") }
                    Section {
                        TextEditor(text: $model.keywords).font(.body).frame(height: 70).disabled(model.settings.asr == .nemotron)
                        HStack {
                            Button { model.importKeywords() } label: { LabelText("action.keywords") }.disabled(model.settings.asr == .nemotron)
                            LabelText(model.settings.asr == .nemotron ? "keywords.unsupported" : "keywords.support").font(.caption).foregroundStyle(.secondary)
                        }
                        LabelText("speaker.unsupported").font(.caption).foregroundStyle(.secondary)
                    } header: { LabelText("section.keywords") }
                    Section {
                        Button { model.chooseDirectory(models: true) } label: { LabelText("action.modelsFolder") }
                        Text(model.settings.modelDirectory).font(.caption).textSelection(.enabled)
                        ForEach((try? ModelStore.catalog) ?? []) { info in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(info.name).font(.headline)
                                    Spacer()
                                    if ModelStore.installed(info.id, root: URL(fileURLWithPath: model.settings.modelDirectory)) { LabelText("model.installed").foregroundStyle(.green) }
                                    else { Button { installChoice = info.id } label: { LabelText("action.install") } }
                                }
                                Text("\(info.license) · \(ByteCountFormatter.string(fromByteCount: info.downloadBytes, countStyle: .decimal)) · \(info.revision.prefix(12))").font(.caption2).textSelection(.enabled)
                            }
                        }
                        if model.installing {
                            ProgressView(value: model.installProgress)
                            Button { model.cancelInstallation() } label: { LabelText("action.cancelInstall") }
                        }
                        Button { model.refreshCapabilities() } label: { LabelText("action.refresh") }
                        if let source = model.settings.source { Text("Apple Speech: \(model.capabilities["speech.\(source.rawValue)"] ?? "unknown")").font(.caption) }
                        Button { installChoice = "speech" } label: { LabelText("action.installSpeech") }.disabled(model.settings.source == nil)
                        if let status = model.capabilities["translation"] { Text("Apple Translation: \(status)").font(.caption) }
                        Button {
                            if let source = model.settings.source, let target = model.settings.target {
                                packConfiguration = TranslationSession.Configuration(source: AppleTranslator.language(source, script: model.settings.chineseScript), target: AppleTranslator.language(target, script: model.settings.chineseScript))
                            }
                        } label: { LabelText("action.installTranslation") }.disabled(model.settings.target == nil || model.settings.target == model.settings.source)
                    } header: { LabelText("section.models") }
                    Section {
                        HStack {
                            Button { model.loadSettings() } label: { LabelText("action.load") }
                            Button { model.saveSettings() } label: { LabelText("action.save") }
                        }
                    } header: { LabelText("section.settings") }
                }.formStyle(.grouped).disabled(model.running)
            }.frame(minWidth: 450, idealWidth: 480, maxWidth: 560)
        }
        .dropDestination(for: URL.self) { urls, _ in guard !model.running else { return false }; model.add(urls); return true }
        .onChange(of: model.selection) { _, value in if let value { model.showPreview(value) } }
        .onChange(of: model.settings.asr) { _, value in if value != .whisper && model.settings.source == nil { model.settings.source = .ko } }
        .onChange(of: model.settings.target) { _, value in if value == nil { model.settings.display = .source } }
        .confirmationDialog(Text("install.confirm", bundle: .module), isPresented: Binding(get: { installChoice != nil }, set: { if !$0 { installChoice = nil } })) {
            Button { if let choice = installChoice { if choice == "speech" { model.installSpeech() } else { model.installModel(choice) } }; installChoice = nil } label: { LabelText("action.install") }
            Button(role: .cancel) { installChoice = nil } label: { LabelText("action.cancel") }
        } message: { LabelText("install.notice") }
        .translationTask(packConfiguration) { session in
            do { try await PackSessionBox(session).prepare(); model.message = "Apple Translation packs ready"; model.refreshCapabilities() }
            catch { model.message = error.localizedDescription }
            packConfiguration = nil
        }
    }
}
