# Architecture

## Scope and state

s7r targets Apple Silicon and macOS 26 or later. SwiftUI and the CLI use the same batch processor.
The initial host uses macOS 27.0 (26A428) and Swift 6.4.2.
No Git repository existed when work started. GOAL_PROMPT.md is a preserved user file.
OST is a read-only reference. s7r does not import OST or link to its files.

## Engine decisions

| Engine | Role | Languages | Timing | Keywords | Acceleration | Assets and license |
| --- | --- | --- | --- | --- | --- | --- |
| Nemotron 3.5 0.6B with MLX Audio Swift 0.1.7 | Default ASR | Explicit ko, en, ja, zh | Streaming sentence ranges | Unsupported | MLX Metal GPU | 756 MB, OpenMDW-1.1 |
| Apple SpeechAnalyzer | Optional ASR | Runtime query for ko, en, ja, Mandarin | File-relative result ranges | AnalysisContext contextual strings | Apple controls hardware | OS-managed assets, Apple terms, size not exposed |
| WhisperKit 1.1.1 | Optional ASR | Multilingual Whisper, including four required languages | Token and word timestamps | Decoder prompt tokens | Core ML, GPU and Neural Engine through framework defaults | Whisper small about 491 MB including tokenizer, MIT |
| Apple Translation | Default translation | Runtime pair status | Retains source segment IDs | Not applicable | Apple controls hardware | Installed packs only for CLI, Apple terms, size not exposed |
| Qwen3-4B-Instruct-2507 4bit with MLX | Local fallback translation | Prompted ko, en, ja, zh, quality requires examples | Retains source segment IDs | Not applicable | MLX Metal GPU, no Neural Engine claim | About 2.28 GB, Apache-2.0 |

The original Qwen3 ASR path in OST returns text without precise word alignment.
The separate Qwen aligner comparison needs further timing work before product integration.
WhisperKit adds an independent local ASR path with timestamps. Only its ASR product is linked.
Qwen translation does not use Whisper translation. Whisper translation targets English and cannot satisfy arbitrary target languages.
Language support claims depend on runtime probes and recorded execution, not this design table.

## Processing

AVFoundation inspects actual audio and video tracks, then decodes audio to temporary PCM on disk.
Sample presentation times preserve video offsets and silence. Bounded buffers avoid loading complete media files.
Apple analyzes the PCM file and finishes at end of input.
Nemotron consumes 1120 ms chunks and flushes its streaming session at end of input.
Whisper reads bounded overlapping windows. Word timing assigns each word to one window ownership interval.
A stable ID connects each source segment to its translation and errors.
Exporters share timing, wrapping, language order, and escaping rules.
The batch processor isolates file errors, reports cancellation, and reserves collision-free output paths.

Models live in the selected project-local model directory. Inference never downloads models.
Only explicit model installation uses the network. Apple asset installation also requires an explicit action.
CLI errors explain unavailable assets and never invoke an installation dialog.
Apple translation pack installation belongs in the GUI translation task.
Chinese script selection is separate from spoken Mandarin recognition.

## Optional features

Speaker diarization remains unsupported until a local model license, alignment, and memory cost pass evaluation.
SpeakerKit exists, but this alone does not prove suitability. No synthetic speaker changes are inferred from silence.
Spanish remains optional and requires a separate recorded execution before a support claim.
The product has no FFmpeg dependency. Additional formats depend on real AVFoundation decoding results.

## Sources

- [Apple SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer)
- [Apple TranslationSession](https://developer.apple.com/documentation/translation/translationsession)
- [WhisperKit source](https://github.com/argmaxinc/argmax-oss-swift/tree/v1.1.1)
- [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm/tree/3.32.3)
- [Whisper small Core ML files](https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/openai_whisper-small)
- [Qwen3 model](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit)
- OST Package.swift, Apple providers, Qwen adapters, vocabulary parser, model catalog (read-only, MIT).

Context7 supplied SpeechAnalyzer file lifecycle, WhisperKit local-only initialization, and MLX model loading examples.
The compiler and pinned dependency source remain authoritative when current documentation differs.

## Validated engine update

Nemotron 3.5 ASR 0.6B 8-bit is now available through the same processor as Apple Speech and Whisper.
MLX Audio Swift 0.1.7 provides a streaming session that trims raw audio history.
MLX Swift LM moved to 3.32.3 to match that dependency family.
The separate ASR comparison uses the same MLX Audio release and records its own lockfile.

Nemotron uses an explicit source locale and a 1120 ms streaming chunk for file processing.
This version does not expose its language auto-detection or keyword boosting.
Whisper remains the auto-detection and decoder-prompt path.
The GUI disables Nemotron vocabulary controls and retains the entered text when they switch engines.

Qwen4 uses its official chat template. A limited consistency rule detects added time-of-day terms.
The engine retries once with corrective instructions. A second failure returns an explicit translation error.
This rule does not detect all translation errors. The original text remains authoritative.

The four-language comparison and 1803-second run support Nemotron as the default for this tested environment.
This selection does not establish a general quality ranking. Read `asr-candidates.md` for the measured scope.
