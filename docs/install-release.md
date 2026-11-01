# s7r 0.1

This archive contains the app, CLI, third-party notices, and matching source files.
Use an Apple Silicon Mac with macOS 26 or later.
The recorded runtime tests used macOS 27.0. macOS 26 did not receive a separate execution test.

Keep the extracted folder together. The CLI needs the resource bundles beside its executable.
Keep the internal `mlx.metallib` links intact.
Model weights and Apple language packs are not included.
The app uses an ad-hoc signature without Apple notarization.
If macOS blocks the downloaded app, use the source build procedure in `source/README.md`.

## App

Open `s7r.app` from the extracted folder.
Select a writable model directory and an output directory.
Select a model and use the explicit installation control.
Add a local file through the file dialog.
Select the input language, then start processing.
Use the file dialog for the validated input path. Finder drag remains unverified in this release.
Read `source/docs/gui-validation.md` for the recorded UI scope and remaining limits.

The default speech engine is Nemotron. Translation is off by default.
Apple Speech, Whisper, Apple Translation, and Qwen translation remain explicit selections.
If Apple Speech reports missing assets, use its preparation button inside the app.

## CLI

Run these commands from the extracted folder:

```sh
./cli/s7r --help
./cli/s7r status
```

If you select Nemotron and accept its model license, install it explicitly:

```sh
./cli/s7r install-model nemotron --accept-license
./cli/s7r transcribe --source ko --output ./Output 'recording.m4a'
```

Audio defaults to TXT. Video defaults to SRT.
The CLI and GUI use the same processing core.
Read `source/README.md` for translation, keyword, subtitle, and batch commands.
Read `source/docs/validation.md` for actual quality results and unsupported paths.

## Source build

The `source` directory contains the matching source files and dependency lockfiles.
Read `source/README.md` for the tested Xcode and Metal Toolchain requirements.
From that directory, build and test with these commands:

```sh
Scripts/swift.sh build
Scripts/swift.sh test
Scripts/package-app.sh
```

The s7r source license is MIT. Read `LICENSE` and the separate notices under `ThirdParty`.
