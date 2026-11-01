# ASR candidates below 4B

## Finding

The current Whisper small model has 244 million parameters. It is a working baseline, not the strongest candidate below 4B.
Three paths merit comparison: Nemotron 3.5 0.6B, Qwen3-ASR 1.7B with a 0.6B aligner, and Whisper large-v3 1.55B.
The user selected Nemotron and Qwen ASR for local comparison. Both completed the four short reference recordings.
Nemotron also completed the long-file test and became the default engine.
Whisper large-v3 and turbo remain research candidates without local measurements.

The removed Qwen3-1.7B model was a text translation model. Qwen3-ASR-1.7B is a separate speech model.
The translation failure does not establish the quality of Qwen3-ASR.

## Candidate fit

| Candidate | Parameters | Required languages | Subtitle timing | Apple Silicon path | License | Assessment |
| --- | --- | --- | --- | --- | --- | --- |
| Whisper small, current | 0.244B | ko, en, ja, zh | Word alignment in WhisperKit | Core ML | MIT in selected Core ML repository | Local execution verified, Korean recognition errors remain |
| Whisper large-v3 | 1.55B | ko, en, ja, zh | Same WhisperKit alignment design | Core ML conversion | Source model card declares Apache-2.0; inspect converted artifact license separately | Lowest integration change, larger model and memory cost |
| Whisper large-v3-turbo | About 0.809B | Multilingual, required four included | WhisperKit-compatible conversion requires artifact inspection | Core ML | MIT | Speed candidate, compare quality against large-v3 |
| Nemotron 3.5 ASR Streaming | 0.6B | ko, en, ja ready; Mandarin broad coverage | MLX Swift implementation returns aligned segments | MLX Swift or NVIDIA NeMo-Speech.cpp | OpenMDW-1.1 upstream | Strong compact candidate, Mandarin needs particular attention |
| Qwen3-ASR plus ForcedAligner | 1.7B + 0.6B = 2.3B | All four for recognition and alignment | Separate word alignment model | MLX Audio Swift supports both models | Apache-2.0 | Strong accuracy candidate, extra alignment and memory cost |
| Nemotron Labs Unified ASR | 0.6B | 25 European languages | Offline and streaming model | Runtime integration requires inspection | OpenMDW-1.1 | Exclude as the four-language default |
| Nemotron Speech Streaming en | 0.6B | English only | Streaming RNNT | MLX Swift exists | Inspect the exact checkpoint | Exclude as the four-language default |
| Parakeet TDT v3 | 0.6B | 25 European languages | Token durations | MLX and Core ML ports exist | Inspect the exact checkpoint | Exclude as the four-language default |
| Voxtral Mini 2507 | 3B | Official list excludes ko, ja, zh | Additional alignment requires inspection | Swift MLX port exists | Apache-2.0 | Exclude for this project's required language set |

## Nemotron details

Nemotron is not limited to the older English checkpoint.
NVIDIA lists 40 language-locales for Nemotron 3.5, with 32 that transcribe without fine-tuning.
Eight additional locales require adaptation. A locale count is not a count of distinct languages.
Korean, Japanese, and English are in the ready tier. Mandarin is in the broad-coverage tier.

For manual language selection and a 320 ms streaming chunk, NVIDIA reports these FLEURS errors:
Korean 7.27% CER, Japanese 12.22% CER, Mandarin 20.03% CER, and English 8.27% WER.
CER means character error rate. WER means word error rate.
These are NVIDIA's published results, not measurements on this Mac.
Different normalization and inference modes prevent a direct ranking against another vendor's table.
H100 throughput results do not establish speed on Apple Silicon.

The current MLX Audio Swift source includes `NemotronASRModel` and returns aligned segments.
Its 8-bit MLX repository lists about 756 MB of files at revision `7279359e4481b5e9e185a318bd618e429c6d86cd`.
The local product measurements below supplement these source-level capabilities.

## Qwen details

Qwen3-ASR supports 30 languages and 22 Chinese dialects.
Its separate aligner covers 11 languages, including all four required languages.
The ASR and aligner together total 2.3B parameters, below the requested 4B limit.
The published comparison reports a 4.90% FLEURS average for ASR 1.7B versus 5.27% for Whisper large-v3 across 12 languages.
This is the model author's comparison. It does not establish a local four-language winner.

The MLX repositories list about 1.61 GB for ASR 1.7B 4-bit and 976 MB for its 0.6B 4-bit aligner.
Their revisions are `78a389c776a5483b2d0d4ea5494e11012e0d6159` and `2f652af86ae0c73fe189b9429225c908ce4bf020`.
Download size and peak runtime memory are different measurements.

## Selection method

Use the same audio, reference text, and normalization for each candidate.
Keep numeral and punctuation differences separate from recognition errors.
Measure four-language accuracy, word boundary errors, model load time, processing time, peak memory, and cancellation.
Include clean speech, noise, proper names, long files, and a Mandarin example.
A short synthetic example proves execution but cannot establish general accuracy.
The completed comparison covers clean synthetic speech and the long repeated-speech fixture.
Natural speech, noise, proper names, and broader Mandarin coverage still need a larger evaluation.

## Official sources

- [NVIDIA Nemotron 3.5 model card](https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b)
- [NVIDIA Nemotron Labs Unified model card](https://huggingface.co/nvidia/nemotron-labs-unified-asr-0.6b)
- [NVIDIA local runtime model guide](https://github.com/NVIDIA/NeMo-Speech.cpp/blob/main/docs/asr/models.md)
- [MLX Swift Nemotron implementation](https://github.com/Blaizzy/mlx-audio-swift/blob/main/Sources/MLXAudioSTT/Models/NemotronASR/NemotronASRModel.swift)
- [MLX Swift Qwen ASR and alignment guide](https://github.com/Blaizzy/mlx-audio-swift/blob/main/Sources/MLXAudioSTT/Models/Qwen3ASR/README.md)
- [Qwen ASR model card and evaluation tables](https://huggingface.co/Qwen/Qwen3-ASR-1.7B)
- [Qwen aligner language support](https://github.com/huggingface/transformers/blob/main/docs/source/en/model_doc/qwen3_asr.md)
- [OpenAI Whisper large-v3 model card](https://huggingface.co/openai/whisper-large-v3)
- [OpenAI Whisper turbo model card](https://huggingface.co/openai/whisper-large-v3-turbo)
- [Mistral Voxtral Mini model card](https://huggingface.co/mistralai/Voxtral-Mini-3B-2507)

Research date: 2026-11-01 (Asia/Seoul). Runtime source on main can change.

## Local comparison

The approved comparison used MLX Audio Swift 0.1.7 and four original synthetic recordings of about five seconds each.
The model loader used only the selected local directories. No inference request reached a remote service.
The benchmark kept raw output in `docs/evidence/asr-bench-*.json` and normalized comparisons in `docs/evidence/asr-comparison.json`.

After punctuation, whitespace, case, and the documented numeral equivalence, Nemotron and Qwen ASR both scored zero CER on these four examples.
Whisper small scored zero on English, Japanese, and Chinese. Its Korean CER was about 3.23% because it wrote `안녕하세여`.
These small synthetic examples do not establish performance on natural speech, noise, or an unseen speaker.

Nemotron loaded in about 0.78 seconds. Its full process took about 9.75 seconds and reached about 446 MB RSS.
Qwen ASR plus alignment loaded in about 4.74 seconds. Its process took about 14.50 seconds and reached about 868 MB RSS.
The first file includes Metal warm-up. Later files do not have equivalent warm-up costs.
Whisper's earlier process timings include model loading and concurrent development work, so they are not a comparable speed measurement.
RSS excludes memory owned by separate OS services and is not total unified memory.

The Qwen aligner returned a Japanese first unit near 1.12 seconds, so timing needs further evaluation.
Nemotron produced sentence ranges with small overlaps and a final whitespace-only segment. The shared normalizer removes those artifacts.
The Qwen loader generated local tokenizer files and printed messages after the JSON record.
The benchmark preserves that raw output and also stores a parsed JSON artifact. Product stdout must remain clean.

The product uses the Nemotron streaming session from version 0.1.7.
That source trims its raw sample buffer. Version 0.1.5 retained the full sample history and cannot satisfy this project's memory rule.
The product completed the 1803-second test in 131.3 seconds with a peak RSS of 941,064,192 bytes on an M4 with 16 GB.
The output retained all 300 normalized reference repetitions, including the final sentence.
Start, middle, and end cues remained on the file timeline. Sentence ends can extend into silence by about one second.
The memory trace stayed near 891 MB after warm-up, rather than retaining the full input.
Some development work ran concurrently. These timings are observations, not isolated performance guarantees.
Read `evidence/long-nemotron-metrics.json` and `evidence/long-nemotron-quality.json` for the trace and comparison.

Nemotron is the default. Whisper remains available for automatic language detection and keyword hints.
Qwen ASR and its aligner remain benchmark-only. Their weights remain local, separate from the deleted text translator.
The earlier Whisper long run missed speech and its final 24 seconds. It does not pass the long-file acceptance criterion.
