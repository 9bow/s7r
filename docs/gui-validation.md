# GUI validation

## Recorded execution

The local `s7r.app` bundle launched with an ad-hoc signature.
The Korean UI displayed engine, source language, translation target, script, output, vocabulary, and model controls.
The model panel showed installed Whisper, Nemotron, and Qwen4 revisions, licenses, sizes, and the project model directory.

The file dialog accepted a Korean filename with spaces. Whisper completed that file and displayed SRT text in the preview.
The CLI configuration file then loaded in the GUI with Nemotron, English, SRT/JSON, and the selected absolute directories.
The same English file completed through the GUI.
Its JSON and SRT matched the CLI output byte for byte. See `evidence/gui-cli-parity.json`.
The GUI saved a configuration file whose decoded values matched the CLI configuration. See `evidence/gui-settings-parity.json`.

The GUI accepted the 1803-second file and displayed transcription progress while the cancel button remained active.
Clicking cancel returned the interface to its idle state with one cancelled job and zero failures.
The task row showed cancellation. The settings controls became available again.
The CLI measured cancellation separately at about 0.66 seconds. GUI click latency was not timed independently.
The output-directory button opened the selected result directory in Finder.
The translation-pack preparation button completed for installed English-to-Korean assets without a new download.

## Reproduction

1. Run `Scripts/swift.sh build` from the project root.
2. Run `Scripts/package-app.sh`.
3. Open `s7r.app`.
4. Select installed Nemotron and an explicit source language.
5. Add a short audio file with the file dialog or a file URL drop.
6. Select SRT and JSON, then start processing.
7. Select the completed row to read the preview.
8. Open the output directory and compare its files with the CLI results.
9. Save the configuration, then load it again.
10. Add a long file and start processing.
11. Click cancel and wait for the cancelled state.

File-URL drag and drop uses the same `AppModel.add` input path as the file dialog.
The successful input run used the file dialog. Follow-up CUA drags did not add an item to the queue.
The cause remains unresolved between the input handler and the cross-window automation.
The native XCUITest project compiled, but execution failed at the window placement menu before the first drag.
The user excluded further XCUITest execution from release 0.1.
Read [the prepared Finder test](../UITests/README.md). No successful Finder drop is claimed.
UI language changes use the four resource directories. They do not change media source or target languages.
Apple speech installation requires a separate explicit download action.
The follow-up installed and exercised Apple Speech assets. Read [the Apple Speech record](apple-speech-validation.md).

A clean-machine Apple translation download was not attempted. The host already had the tested translation packs.

The final rebuilt app started with Nemotron, Korean source, translation off, and automatic output formats.
The Nemotron vocabulary import button was disabled. All three selected production models appeared installed.

The follow-up GUI Apple Speech run completed a Korean file and showed the SRT preview.
Its source segments, word times, and SRT bytes match the CLI output.
The GUI needed its own explicit asset preparation after the CLI preparation.
