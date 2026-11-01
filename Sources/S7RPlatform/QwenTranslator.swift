import Foundation
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import S7RCore
import Tokenizers

public actor QwenTranslator {
    private var container: ModelContainer?
    private var loadedRoot: String?
    public init() {}
    public func translate(_ text: String, from source: Language, to target: Language, settings: Settings) async throws -> String {
        try Task.checkCancellation()
        if source == target { return target == .zh ? Captions.chinese(text, script: settings.chineseScript) : text }
        let root = URL(fileURLWithPath: settings.modelDirectory).standardizedFileURL
        try ModelStore.require("qwen", root: root)
        if container == nil || loadedRoot != root.path {
            container = try await LLMModelFactory.shared.loadContainer(from: root.appendingPathComponent("qwen3-4b"), using: #huggingFaceTokenizerLoader())
            loadedRoot = root.path
        }
        guard let container else { throw S7RError("Qwen model did not load.") }
        let targetName = target == .zh ? (settings.chineseScript == .traditional ? "Traditional Chinese" : "Simplified Chinese") : target.name
        let prompt = "Translate the user text from \(source.name) to \(targetName). Return only the translation. Do not add, omit, or infer information. Preserve names, dates, and times. Preserve unspecified AM or PM. Use natural target-language wording for audio and video captions. /no_think"
        var feedback = ""
        for attempt in 0..<2 {
            let instruction = prompt + feedback
            let prepared = try await container.prepare(input: UserInput(chat: [.system(instruction), .user(text)], additionalContext: ["enable_thinking": false]))
            let stream = try await container.generate(input: prepared, parameters: GenerateParameters(maxTokens: 1024, temperature: 0, topP: 1, topK: 0))
            var output = ""
            var reachedLimit = false
            for await generation in stream {
                try Task.checkCancellation()
                if case .chunk(let text) = generation { output += text }
                if case .info(let info) = generation { reachedLimit = info.generationTokenCount >= 1024 }
            }
            output = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !output.isEmpty, !output.contains("<think>"), !output.contains("</think>"), !reachedLimit else { throw S7RError("Qwen returned empty, incomplete, or reasoning text. The source segment is preserved.") }
            if TranslationFidelity.addsDayPeriod(source: text, translation: output) {
                guard attempt == 0 else { throw S7RError("Qwen added a time of day that is absent from the source. The source segment is preserved.") }
                feedback = " The previous translation was incorrect: \(output). It added a time of day absent from the source. Translate the original text again. Keep clock times ambiguous. Do not add morning, afternoon, evening, AM, or PM. Return all original sentences in the target language."
                continue
            }
            return target == .zh ? Captions.chinese(output, script: settings.chineseScript) : output
        }
        throw S7RError("Qwen translation failed the factual consistency rule.")
    }
}
