# Follow-up implementation audit

The goal remains open because Finder drag acceptance lacks a successful GUI test.
This audit inspects existing evidence for unchanged engines and repeats execution for the changed processing paths.
The current request authorizes a Git commit and push after the available tests pass.

## Corrected behavior

The CLI now separates option names, option values, and positional arguments before it reads a saved configuration.
Previously, `--help` inside translation text printed help, and `--config` after `--` triggered a configuration read.
The regression script reproduced the old behavior before the new build passed all 11 cases.
CLI keyword arguments now replace saved keywords. Repeated CLI keyword arguments still combine terms and remove duplicates.
An empty `--keywords` value clears saved terms.

SRT and SMI exports now reject a page whose start and end round to the same millisecond.
Previously, short intervals with several caption pages produced zero-duration cues.
The regression test also makes sure that TXT and JSON preserve the source text for these intervals.

Apple Translation discards a session after an error or cancellation.
Apple documents that [future requests on a cancelled session fail](https://developer.apple.com/documentation/translation/translationsession/cancel()).
The real regression test failed on the previous code with `TranslationError.Cause.alreadyCancelled`.
The corrected code completed another translation through the same engine instance.
The test uses installed Korean-to-English packs and does not request a download.
The test also exposed a 72.22-second wait after cancellation.
The wrapper now returns cancellation without waiting for the native request to finish.
It cancels the OS session and discards late results. The OS controls when native work ends.
The measured cancellation response was about 0.000052 seconds. The complete test, including the later retry, still took 74.967 seconds.
These are host observations, not latency guarantees.

The input script no longer assumes that English Apple Speech assets are absent.
All four required speech assets are installed on this host.
The script now tests a missing Whisper model directory alongside a missing Nemotron model directory.
The Nemotron script now fails if execution fails or normalized fixture text differs from the reference.

The final run passed 14 tests, including the real Apple cancellation test.
The CLI option script passed 11 cases. Four real Nemotron transcripts matched their normalized reference sentences.
Read `evidence/follow-up-tests.log`, `apple-translation-cancellation-before.log`, and `follow-up-summary.json` under `docs/evidence` for the raw results.
The refreshed native capability query is in `evidence/follow-up-status.json`.

## Requirement evidence

Paths below are relative to the project root. Existing execution records remain limited to their recorded fixtures and environment.
The earlier GUI records do not prove Finder drop acceptance.

| Requirement | Implementation and inspected evidence | State |
| --- | --- | --- |
| macOS 26+, Apple Silicon, SwiftUI and CLI | `Package.swift`, `Sources/S7RApp`, `Sources/s7r`, `docs/architecture.md` | Implemented. execution host uses macOS 27 |
| Local processing, separate explicit downloads, no paid service | Engine adapters load local directories. only explicit installation calls download APIs | Implemented |
| Project-local work and independent product | Package dependencies contain no OST path. original goal file remains unchanged | Preserved |
| Single file, multiple files, mixed media, directories | `Inputs.expand`, `MediaProcessor`, refreshed `evidence/input-validation.json` and `batch-validation.json` | Executed |
| Optional recursion and duplicate removal | `directoryRecursionAndDuplicates`, refreshed input integration record | Passed |
| Real audio track and decoding, required five formats | `MediaDecoder`, `evidence/real-validation.json`, `mp3-summary.json` | Recorded WAV, M4A, MP3, MP4, MOV. AIFF also recorded |
| Audio TXT and video SRT defaults | `MediaProcessor` selects defaults after actual track inspection | Implemented. earlier CLI records |
| Progress, file failures, final summary, cancellation | `BatchProcessor`, refreshed mixed-batch and cancellation records | Two successes, two isolated failures. exit 130 on cancellation |
| Output folder, collisions, explicit overwrite | `Exporter.write`, `collisionAndOverwrite`, refreshed collision batch | Existing bytes preserved |
| Bounded audio buffers, offsets, final speech | `MediaDecoder`, streaming Nemotron, bounded Whisper windows, long-file transcript | Recorded offset and final speech. Whisper long-file limit remains documented |
| Four required speech languages | Refreshed `evidence/nemotron-product.json`. Apple and Whisper language records | Actual execution. normalized Nemotron references match |
| Mandarin and Chinese script selection | Language enum separates script. `chinese-script-and-identity.json`, Unicode tests | Recorded simplified-to-traditional output |
| Separate source, target, ASR, and translation choices | Shared `Settings`, GUI pickers, CLI parser | Implemented |
| Manual source choice and supported automatic detection | Whisper-only automatic choice, runtime Apple queries, `auto-validation.json` | Recorded all four detected languages |
| Translation off by default, identity bypass | `Settings`, `MediaProcessor`, identity record and CLI regression cases | Passed |
| Source, translated, bilingual, and reversed order | `Exporter`, bilingual tests and real player frames | Passed within recorded scope |
| Stable IDs, times, translation failures | Normalization precedes translation. forced JSON on partial results | Refreshed real partial-failure test preserves source and segment errors |
| TXT, SRT, SAMI, JSON with segment data | `Exporter`, core tests and `export-validation.json` | Passed. JSON retains optional words and speaker IDs |
| Shared caption limits, CJK wrapping, sentence and time boundaries | `Captions`, shared settings and core tests | Passed. new millisecond-duration gate |
| File time order and nonoverlapping captions | Normalization, offset records, long transcript, strict export parser | Recorded. engine timing limits remain explicit |
| UTF-8, subtitle escaping, SAMI class and final clear | Export tests and `docs/player-validation.md` frames | Actual VLC renderer evidence. other players untested |
| Apple Speech and Translation support queries | `AppleEngines.swift`, recorded probes and current native status query | Runtime-dependent. installed ko-to-en translation tested again |
| CLI without installation dialogs, explicit GUI pack preparation | Installed-only translator initialization. GUI translation task and preparation record | Recorded. clean-machine pack download remains untested |
| Non-Apple ASR and translation paths | Nemotron and Whisper adapters, Qwen translator, four-language and 12-direction records | Local model execution recorded |
| Timed ASR, separate arbitrary-language translation | Nemotron sentence timing, Whisper/Apple word timing, separate translators | Implemented. no text-only ASR used for precise subtitles |
| Hardware and model information | Engine defaults, fixed model catalog, GUI model panel, current model receipts | Three models present. no unsupported hardware selector |
| Direct and UTF-8 keyword hints | Apple contextual strings, Whisper prompt tokens, `keyword-validation.json` | Actual before/after example. Nemotron control disabled |
| GUI inputs, queue, progress, cancel, output folder and preview | `App.swift`, `AppModel.swift`, GUI execution and parity records | File-dialog processing recorded. Finder drop remains open |
| GUI controls, model preparation and four UI languages | Shared settings and four localized resource files | Implemented. existing GUI records |
| GUI and CLI parity | `gui-cli-parity.json`, `gui-settings-parity.json`, Apple GUI record | Earlier real output and configuration equality recorded |
| Optional diarization and Spanish | `docs/optional-features.md`, disabled or absent controls | Explicitly unsupported or unvalidated |
| Short and 30-minute performance, memory and synchronization | `long-nemotron-metrics.json`, `long-nemotron-quality.json`, short benchmark records | 300 repetitions retained. timing and memory limits documented |
| Build, automated tests, CLI and manual GUI procedures | `Scripts`, core tests, README, `docs/gui-validation.md` | Available CLI tests repeated. GUI gate remains open |
| Legal fixtures, references, quality criteria and failure cases | `docs/media-sources.md`, raw transcripts, translation review and ASR comparison | Synthetic fixture scope stated. no general accuracy claim |

## Reproduce

Run these commands from the project root after the selected local models are ready:

```sh
Scripts/swift.sh build
Scripts/swift.sh test
python3 Scripts/validate-cli-options.py
python3 Scripts/validate-inputs.py
python3 Scripts/validate-batch.py
python3 Scripts/validate-nemotron.py
python3 Scripts/validate-exports.py
```

If Korean-to-English Apple Translation packs are installed, run the real cancellation regression:

```sh
S7R_TEST_APPLE_TRANSLATION=1 Scripts/swift.sh test --filter appleTranslationRecoversAfterCancellation
```

That test is skipped unless the environment variable equals `1`.
Use normal macOS service access for actual media and Apple model execution.
The restricted command sandbox reports Apple services as unsupported even when the native process finds installed assets.

## Remaining gate

The Mac was locked during this audit. Computer-use tools could not inspect or operate native app windows.
The Finder drag handler remains unverified. No GUI change or successful drag result is claimed in this follow-up.
After the Mac is unlocked, test real file and folder drops, duplicates, recursion, processing, preview, and cancellation.
Use the existing manual procedure without another XCUITest run.
Completion requires that evidence or a demonstrated fix followed by successful execution.
