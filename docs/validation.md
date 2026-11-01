# Validation record

## Scope

The CLI, local app, three production models, and test artifacts are present in this project.
The recorded results below use real local models in addition to deterministic core tests.
The evidence does not establish general accuracy on natural conversations or every media codec.
Unexecuted paths remain listed separately.

Model downloads, Metal Toolchain installation, and portable VLC execution received explicit user authorization.
No test sends media, source text, or translated text to a remote inference service.
The old Qwen3-1.7B text translation weights were deleted at the explicit request of the user.
The separate Qwen ASR 1.7B weights remain for the approved comparison.

## Environment

The test date was November 1, 2026, in Asia/Seoul.
The host used Apple M4, 16 GB memory, macOS 27.0 build 26A428, Swift 6.4.2, and the macOS 27.2 SDK.
Metal Toolchain 27B47 downloaded about 838.9 MB and enabled MLX shader compilation.
The target remains Apple Silicon with macOS 26 or later. This host did not test macOS 26 separately.

The restricted command sandbox blocked some macOS media and translation services.
Real media tests ran with access to those local OS services. Normal app execution uses those services too.
A sandbox failure is not counted as successful inference.
The final batch rerun first failed inside that sandbox, then passed with local service access.

## Stage record

| Stage | Implementation and recorded evidence |
| --- | --- |
| 1 Research | Runtime Apple probe, local Whisper, installed Apple Translation, missing-asset errors, and engine selection in `architecture.md` |
| 2 Core and CLI | Real audio TXT, video SRT, required media types, offsets, silence, corrupt files, audio-free video, and Korean paths |
| 3 Batch and exports | Mixed success/failure, recursion, duplicates, collisions, explicit overwrite, cancellation, strict subtitle parsing, and VLC rendering |
| 4 Engines and languages | Four-language Nemotron and Whisper, Apple/Qwen translation in 12 directions, identity bypass, Chinese scripts, and actual keyword delivery |
| 5 GUI | Actual model execution, preview, output directory, configuration round-trip, CLI parity, progress, cancellation, and installed-pack preparation |
| 6 Performance | Short model measurements and a complete 1803-second Nemotron run with a stable memory trace |
| 7 Final artifacts | Build, 12 passing core tests, signed local app, commands, model notices, media sources, and the limits below |

## Core, input, and output

The final test run passed 12 Swift Testing tests. See `evidence/unit-tests-final.log`.
Tests cover time ordering, wrapping, escaping, bilingual pages, partial translation, configuration, collisions, and cancellation.
They also cover recursion, duplicate paths, invalid arguments, missing models, and preservation of file times.

Real decoding succeeded for WAV, M4A, MP3, MP4, MOV, and AIFF.
Silence produced an empty transcript with a no-speech warning. Corrupt MP4 and audio-free MOV returned file failures.
Three-second video offsets produced the first Whisper cue near 3.2 seconds and the first Nemotron cue at 3.36 seconds.
The last utterance remained in the Nemotron output.
See `evidence/real-validation.json`, `mp3-summary.json`, and `nemotron-silence.json`.

The final real batch completed two files and isolated two failures.
A second batch preserved existing output bytes and selected new names.
A missing Qwen receipt produced a partial result with source text, segment errors, and a forced JSON export.
The test restored the receipt after the failure case.
The final cancellation returned exit code 130 after about 0.66 seconds.
No raw cancellation exception appears in the final job summary.
See `evidence/batch-validation.json` and `cancel-summary.json`.

Directory tests cover default nonrecursive input, optional recursion, and duplicate removal.
Argument errors return code 2. Missing models and unavailable installed speech assets return promptly with code 1.
The Apple capability query has a 30-second watchdog. It does not wait indefinitely for a GUI.
See `evidence/input-validation.json` and `installer-validation.json`.

The strict export parser accepted SRT sequence numbers, timestamps, positive durations, order, line limits, and JSON IDs.
It also accepted SAMI event order, escaping, UTF-8 text, and the final clear event.
The real VLC renderer showed both languages and cleared the final caption in SRT and SMI.
Read `player-validation.md` for images, commands, and the distinction between renderer output and interactive GUI playback.

## Language and quality criteria

The four short fixtures use original text and installed macOS voices. Read `media-sources.md` for the source and commands.
Character error rate compares normalized reference text with model output.
Normalization removes punctuation, case, and whitespace. It equates the written numeral nine with 9 for each language.
The initial English-only numeral rule was invalid for CJK comparisons and was replaced before the final comparison.

Nemotron and Qwen ASR each returned zero normalized character error on all four short examples.
Whisper small returned zero on English, Japanese, and Mandarin, and about 3.23% on Korean without hints.
This limited result does not rank the models across natural speech, noise, accents, or proper names.
See `evidence/asr-comparison.json` and `nemotron-product.json`.

Whisper automatic detection returned en, ko, ja, and zh on the four files.
Chinese traditional output and identical-language translation bypass completed without a Qwen receipt.
The test restored that receipt afterward. See `auto-validation.json` and `chinese-script-and-identity.json` in `evidence`.

Apple Translation reported installed packs for all 12 directed pairs among the four languages.
All 12 pairs executed with the original reference texts. Installed translation ran without a UI or new download.
The GUI preparation action also completed for installed English-to-Korean packs.
Apple does not support the Hans-to-Hant pair as translation on this host. Local script conversion handles that case.

Qwen4 also executed all 12 directions after the corrective retry was added.
The review criterion requires the greeting, subtitle-test meaning, meeting, tomorrow, and nine to remain present.
It also rejects an invented date or time-of-day. The final recorded examples meet that narrow factual criterion.
Lexical defects remain: English-to-Korean translates local as 지역, and Korean-to-Japanese repeats tomorrow.
English-to-Japanese also uses an awkward spelling for subtitle.
The app does not claim professional translation quality. See `evidence/real-validation.json` for every unmodified output.

The old Qwen text 1.7B model omitted content and introduced dates or times. It failed this criterion.
An early Qwen4 output also introduced morning. Its earlier failure artifacts remain in `evidence/qwen4-*.json`.
The product now retries once when its limited time-of-day rule detects an addition.
A second failure becomes an explicit segment error. This rule does not detect every semantic error.
The final 12-direction results are in `real-validation.json`, rather than the earlier single-text probe files.

Whisper received actual decoder prompt tokens from a UTF-8 vocabulary file.
On the same Korean recording, 안녕하세여 changed to 안녕하세요 with the hints.
See `evidence/keyword-validation.json`. This single example does not guarantee an accuracy gain.
Apple receives contextual strings. The follow-up actual Apple run completed with two hints.
The same Korean fixture was already correct without hints, so no improvement is claimed.
Nemotron exposes no keyword hint control.

## Performance and timing

Nemotron is the default engine after the local comparison and long-file result.
The separate short benchmark loaded Nemotron in about 0.78 seconds and Qwen ASR plus alignment in about 4.74 seconds.
Their full process times were about 9.75 and 14.50 seconds, respectively.
Peak resident process memory was about 446 and 868 MB, respectively.
The first file includes Metal warm-up. These measurements do not establish a general speed ranking.
Qwen alignment placed the first Japanese unit near 1.12 seconds. Qwen ASR remains benchmark-only pending better timing evidence.

The long file contains 300 reference repetitions across 1803.01425 seconds, with speech at `3 + 6n` seconds.
Nemotron completed it in 131.303 seconds and returned 547 segments.
The concatenated output contained all 300 exact normalized repetitions, including the last one.
The first cue starts at 3.36 seconds. A middle greeting starts at 897.2 seconds, near its expected 897-second onset.
The last greeting starts at 1797.04 seconds. The last sentence remains through the file end.
Sentence ends can extend into silence by about one second. These ranges are not precise word boundaries.

Peak sampled resident memory was 941,064,192 bytes. The trace settled near 891 MB after warm-up.
It did not grow with the retained raw audio duration in this run.
The output segment array still grows with the amount of recognized text.
RSS excludes separate OS services and does not measure all unified GPU memory.
Concurrent development work affected the host during parts of the run. These observations are not performance guarantees.
See `evidence/long-nemotron-metrics.json` and `long-nemotron-quality.json`.

The earlier Whisper long run took about 351 seconds and missed repeated speech, including the final 24 seconds.
Its memory remained bounded, but it failed the long-file quality criterion.
A later minimum-word-duration correction did not receive another long Whisper run.
Use Nemotron for long files. Whisper remains an optional automatic-language and keyword path with this stated limit.

## GUI and unexecuted paths

The GUI and CLI produced identical JSON and SRT for the same real Nemotron input and configuration.
The GUI saved and loaded equivalent configuration values. Processing remained responsive, and the cancel button stopped a long job.
Read `gui-validation.md` and its linked parity artifacts.

Follow-up cross-application CUA drag attempts did not add an item.
The separate XCUITest project compiled, but execution failed at the window placement menu before the first drag.
Further XCUITest execution is excluded from release 0.1 at the explicit request of the user.
Finder drop acceptance remains open. Read [the prepared test](../UITests/README.md).
The implemented URL drop calls the same input expansion method as the tested file dialog.
A clean-machine Apple translation pack download was not attempted because the tested packs were already installed.
The initial run lacked Apple Speech assets. The follow-up installed and exercised all four required languages.
Read [the Apple Speech record](apple-speech-validation.md) for actual transcripts, word times, GUI parity, offsets, silence, and cancellation.
The native VLC GUI was unavailable to automation. The real renderer test is recorded separately.
Speaker diarization is unsupported. Spanish is not exposed because it lacks a recorded product run.
No macOS 26 machine, Intel Mac, Windows host, or Linux host received execution tests.

## Reproduce

Run these commands from `/Users/reserve/Workspace/s7r` after Xcode and the selected models are ready:

```sh
Scripts/swift.sh build
Scripts/swift.sh test
Scripts/package-app.sh
open s7r.app
python3 Scripts/validate-real.py
python3 Scripts/validate-nemotron.py
python3 Scripts/validate-inputs.py
python3 Scripts/validate-batch.py
python3 Scripts/validate-exports.py
python3 Scripts/measure-long.py --engine nemotron
```

The Python scripts require the recorded fixtures in `.validation` and write fresh evidence into `docs/evidence`.
Run the media scripts with normal access to macOS media services. The restricted agent sandbox cannot provide every OS service.
The GUI manual procedure is in `gui-validation.md`. VLC commands are in `player-validation.md`.
The benchmark package and its lockfile remain separate from the production package.

The follow-up Apple status query returned supported rather than installed for most translation pairs.
The earlier 12-direction translation results remain historical execution evidence. Prepare missing translation packs explicitly before reuse.

## Release 0.1 preparation

The optimized Release build completed, and the packaged app reports version 0.1.
The extracted CLI completed Nemotron, Whisper, and Qwen execution with the original build resource bundles temporarily hidden.
The test restored those bundles after execution.
The Release GUI completed two Korean files selected through the folder dialog.
Read `evidence/release-0.1/validation.json` and `gui-and-archive.json`.
Finder drag acceptance remains open, so remote publication has not started.
