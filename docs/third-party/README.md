# Third-party notices

The app bundle contains these dependency notices in `Contents/Resources/ThirdParty`.
`Package.resolved` records the exact source revisions. `Package.swift` records the direct version requirements.
OST supplied reference patterns under its MIT license. The app has no runtime dependency on OST.

## Selected models

| Model | Revision | Download bytes | License | Local directory |
| --- | --- | ---: | --- | --- |
| [Nemotron 3.5 ASR 0.6B 8bit](https://huggingface.co/mlx-community/nemotron-3.5-asr-streaming-0.6b-8bit) | `7279359e4481b5e9e185a318bd618e429c6d86cd` | 756243376 | [OpenMDW-1.1](https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b/blob/main/LICENSE) | `Models/nemotron-0.6b` |
| [Whisper small Core ML](https://huggingface.co/argmaxinc/whisperkit-coreml) | `0f63a7800b00dd0226abd051b906c246e1907482` | 490669497 | [MIT](https://huggingface.co/argmaxinc/whisperkit-coreml/blob/main/LICENSE) | `Models/whisper-small`, `Models/whisper-tokenizer` |
| [Qwen3-4B-Instruct-2507 4bit](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit) | `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b` | 2278969697 | [Apache-2.0](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507/blob/main/LICENSE) | `Models/qwen3-4b` |

The Whisper total includes tokenizer files. Model weights remain outside the app bundle.
Apple manages its speech and translation assets under Apple terms. The app does not redistribute them.

The separate benchmark catalog records Qwen ASR and alignment models under Apache-2.0.
Read [the comparison](../asr-candidates.md) for their revisions and scope.
Portable VLC is a temporary test tool. It is not included in the app bundle.
