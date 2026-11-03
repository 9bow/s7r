# s7r

s7r transcribes local audio and video files on Apple Silicon Macs with macOS 26 or later.
The CLI and SwiftUI app share file decoding, language rules, translation, subtitles, and batch processing.
Nemotron is the default local speech engine. Translation is off by default.
Read [the measured results and limits](docs/validation.md) before using the output.

## Build and launch

The tested host uses macOS 27.0, Swift 6.4.2, and the Xcode 27.2 SDK.
MLX requires the Apple Metal Toolchain. If `xcrun metal --version` fails, install that component through Xcode.
The equivalent installation command is `xcodebuild -downloadComponent MetalToolchain`.
That command downloads and installs Apple development tools outside this project.

From the project root, build the CLI and app:

```sh
Scripts/swift.sh build
Scripts/package-app.sh
open s7r.app
```

On the tested Swift toolchain, executables are in `.build/out/Products/Debug`.
The app bundle stays in the project root and includes a dictation icon.
The app saves output beside each input file by default.
Clear the “Save beside each input file” checkbox to select a separate output folder.
Use the refresh icon above the file list to reload the added folders.
If you add individual files, refresh reloads their parent folders.
The “Include subfolders” checkbox controls subfolder traversal during refresh.

Run automated tests:

```sh
Scripts/swift.sh test
```

The legacy native SwiftPM build can compile Swift code but does not produce MLX Metal shaders.
Use the default build for Qwen and Nemotron execution.
The app uses an ad-hoc signature without Apple notarization.

## Model preparation

Inference never downloads models. Select an engine and install its model explicitly.
The GUI shows each model's revision, license, size, location, and installation state.
The model catalog pins public files by repository revision and checks sizes and available SHA-256 hashes.

Inspect runtime support and model state:

```sh
.build/out/Products/Debug/s7r status
```

Install only the models that you select:

```sh
.build/out/Products/Debug/s7r install-model whisper --accept-license
.build/out/Products/Debug/s7r install-model nemotron --accept-license
.build/out/Products/Debug/s7r install-model qwen --accept-license
```

Whisper small uses about 491 MB, including its tokenizer.
Nemotron 3.5 0.6B 8-bit uses about 756 MB.
Qwen3-4B-Instruct-2507 4-bit uses about 2.28 GB.
Download size is not peak runtime memory.
Models use `~/.cache/s7r` by default in both the app and CLI.
Model folders include `nemotron-0.6b`, `whisper-small`, `whisper-tokenizer`, and `qwen3-4b`.
Use the model folder selector or `--models PATH` to select another root.
To reuse the existing project models, select the project’s `Models` folder.
An empty `outputDirectory` in Settings JSON saves output beside each input file.
A nonempty value selects a separate output folder.
See [model sources and licenses](docs/third-party/README.md).

Apple manages its own assets. The CLI uses installed translation packs and never opens an installation dialog.
The GUI provides an explicit translation-pack preparation action.
Apple Speech executed all four required languages in the [follow-up test](docs/apple-speech-validation.md).
If the GUI still reports missing speech assets after CLI preparation, use its explicit speech preparation button.
For Apple Speech, install the selected language through the GUI or this explicit command:

```sh
.build/out/Products/Debug/s7r install-speech --source ko
```

Apple does not expose model revision, download size, or asset storage control through these APIs.
A missing or unsupported asset returns an error. The app does not switch engines silently.

## CLI use

Convert audio to TXT with the default Nemotron engine:

```sh
.build/out/Products/Debug/s7r transcribe --source ko 'recording.m4a'
```

Convert video to SRT. Select an output folder:

```sh
.build/out/Products/Debug/s7r transcribe --source ja --output ./Output 'meeting.mp4'
```

Translate and export both languages:

```sh
.build/out/Products/Debug/s7r transcribe --source en --target ko \
  --translator qwen --display bilingual --format srt,smi,txt,json \
  --order sourceFirst --line-length 42 --max-lines 2 'meeting.mp4'
```

For Mandarin speech, use `--source zh`. Select `--chinese traditional` or `--chinese simplified` for Chinese output text.
The script selection does not select a different spoken language.
Translation is off by default. An identical source and target bypass the translation engine.
`--source auto` is available only with `--asr whisper` in this version.
For keyword hints, select Whisper or Apple Speech. Use `--keywords TEXT` or `--keywords-file FILE`.

Pass multiple files or directories. Subfolder traversal is off unless you pass `--recursive`.
The batch removes duplicate file paths and inspects actual audio tracks instead of trusting file extensions.
One file failure does not stop the remaining files.
Existing outputs receive numbered names. Use `--overwrite` only when you want to replace existing outputs.
The tool does not overwrite its input file.

`--help` lists every option. `--config FILE` loads a complete Settings JSON file before CLI overrides.
Use `--save-config FILE` or the GUI configuration buttons to save that file.
The CLI prints one JSON summary to stdout and progress records to stderr.
Exit codes are 0 for success, 1 for file or partial translation failure, 2 for invalid arguments, 70 for setup failure, and 130 for cancellation.
Press Control-C to cancel a batch.

CLI keyword arguments replace saved keywords. Repeated `--keywords` and `--keywords-file` arguments combine their terms and remove duplicates.
Use `--keywords ''` to clear saved keywords. After `--`, all arguments are input paths or literal translation text.

## Subtitles and translation

Video defaults to SRT. Audio defaults to TXT.
SRT, SAMI (SMI), TXT, and JSON are available for either media type.
JSON preserves segment IDs, file-relative times, source text, translation, errors, words, and optional speaker IDs.
Translation failures preserve source text and force a JSON export.
An incomplete translation receives a partial result and a nonzero exit code.

Bilingual cues show the source and translation in one cue. The order is configurable.
The line limit counts grapheme clusters, including Chinese, Japanese, and Korean text.
Very long captions are divided into timed pages. Translation page timing divides the source interval proportionally.
That pagination is not word alignment for the translated speech.
SRT and SMI exports reject pages whose duration rounds to zero milliseconds. Increase caption limits or select TXT or JSON for those segments.
SMI uses a single language class to keep both languages visible together.
VLC 3.0.24 rendered both languages and cleared the final cue in the recorded test.
Read [the player test and its limits](docs/player-validation.md). Other players remain untested.

Keyword hints accept direct text or a UTF-8 file with one term per line.
Apple receives contextual strings. Whisper receives decoder prompt tokens.
Nemotron keyword hints are unsupported and disabled.
Hints do not guarantee recognition and do not perform text replacement.

## Support and limits

The required languages are Korean, English, Japanese, and Mandarin Chinese.
Runtime support, installed assets, and measured quality are separate facts.
Read [actual language results](docs/evidence/real-validation.json) and [the ASR comparison](docs/asr-candidates.md).
Synthetic fixtures establish execution, not general accuracy on meetings or noisy recordings.
Translation models can add, omit, or mistranslate content. Review important captions against the audio.

The recorded AVFoundation tests decoded WAV, M4A, MP3, MP4, MOV, and AIFF.
Other formats depend on the OS decoder and are not promised.
The tool selects the first audio track. It does not mix multiple tracks.
Video re-encoding and burned-in captions are outside the product scope.
Audio decoding uses temporary PCM files in `/private/tmp`. They are removed after each job.
A forced process termination can leave a temporary job directory.

Finder drag reception remains unverified after unsuccessful CUA attempts. The file dialog completed real processing.
The native UI test failed before the first drag. Further XCUITest execution is excluded from release 0.1.
Read [the UI test record](UITests/README.md). Use the file dialog for the validated input path.

Speaker diarization is unsupported. No speaker identity is inferred from silence.
Spanish remains unvalidated and is not exposed as a supported language.
There is no server, paid inference service, telemetry, or media upload path.

## Reproduce development evidence

The original fixture sentences, installed macOS voices, and generation commands are in `Scripts` and `docs/evidence`.
Media stays in the ignored `.validation` folder. The project does not distribute third-party recordings.
Run `Scripts/validate-real.py` after preparing the four short fixtures.
Run `Scripts/measure-long.py` after `Scripts/make-long.swift` creates the repeated-speech fixture.
The default Nemotron completed all 300 reference repetitions in the 1803-second fixture.
On an M4 with 16 GB, the process took 131.3 seconds and reached 941 MB RSS.
RSS measures resident process memory. It excludes separate OS services and does not represent total GPU memory.
The trace stabilized instead of retaining all raw audio. These results are not a general speed or accuracy promise.
The recorded Whisper long run omitted speech, including the final 24 seconds. Use Nemotron for long files.
Whisper remains available for automatic language detection and keyword hints.
Nemotron provides sentence timing. Cue ends can extend into silence by about one second in this fixture.

The separate `Benchmarks` package compares Nemotron and Qwen ASR without a network inference request.
Its dependency versions and outputs are recorded separately from the product.
The removed Qwen3-1.7B text translator is not Qwen3-ASR-1.7B.
The former failed local translation evaluation and was deleted at the user's request.

## Output example

A bilingual SRT cue keeps both languages at the same time:

```srt
1
00:00:03,360 --> 00:00:06,000
Hello, this is a local subtitle test.
안녕하세요. 이것은 로컬 자막 테스트입니다.
```

The JSON output keeps the corresponding source segment ID, source text, and translation separately.
Read [the GUI procedure](docs/gui-validation.md), [media sources](docs/media-sources.md), and [optional feature status](docs/optional-features.md).
Read [the follow-up audit](docs/improvement-validation.md) for current fixes, regression tests, and the remaining GUI gate.

## Release packaging

`VERSION` identifies the app and archive version. The current release tag is `0.2`.
After the final acceptance tests pass, build and package the release from the project root:

```sh
Scripts/swift.sh build -c release
Scripts/package-release.sh
```

Quit the running local app before packaging. The packaging script replaces the project-local app bundle.
The script writes an app and CLI archive plus `SHA256SUMS` under the ignored `dist` directory.
The archive includes the source files selected by Git and the third-party notices.
Model weights, caches, test media, and generated output remain outside the archive.
The archive guide and matching source files accompany the binaries.
Read [the archive guide](docs/install-release.md) and [the 0.2 release notes](docs/releases/0.2.md).

## License

s7r source uses the [MIT license](LICENSE). Dependency and model licenses remain separate.
Read [the third-party notices](docs/third-party/README.md) for those terms and source links.
