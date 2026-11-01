# Optional features

## Speaker diarization

Speaker diarization assigns consistent speaker labels within a file. It does not infer identity or separate audio sources.
The Argmax package offers SpeakerKit with a Pyannote path. Its default model repository is `argmaxinc/speakerkit-coreml`.
The SDK uses MIT terms. The public model repository declares CC-BY-4.0 and does not require a download gate.
These are separate licenses.

No diarization weights were selected or downloaded for this goal.
Peak memory, four-language reliability, and alignment with the selected ASR remain unmeasured.
The feature is therefore unsupported in the UI and has no enabled control.
The product never infers speaker changes from silence or sentence order.

A future implementation must record model attribution, speaker embedding cost, memory, and alignment errors before enabling speaker output.
The JSON schema reserves an optional `speakerID` field without inventing labels.

## Spanish

Nemotron's official model card lists Spanish as ready for transcription. Qwen ASR and Whisper also list Spanish support.
The current acceptance work covers the four required languages.
Spanish has no recorded product execution, so the app does not expose it as a supported language.
This optional work did not delay the required language paths.

## Sources

- [SpeakerKit model repository and license](https://huggingface.co/argmaxinc/speakerkit-coreml)
- [SpeakerKit implementation](https://github.com/argmaxinc/argmax-oss-swift/tree/v1.1.1/Sources/SpeakerKit)
- [Nemotron language tiers](https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b)
- [Qwen ASR languages](https://huggingface.co/Qwen/Qwen3-ASR-1.7B)
