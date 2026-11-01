# Finder drag test

The test source and project passed build-for-testing on Apple Silicon.
The attempted execution failed at the window placement menu before the first drag.
The user excluded further XCUITest execution from release 0.1. Finder drag acceptance remains unverified.

The test uses real Finder elements and native mouse drags between applications.
It covers a file, a duplicate file, a directory without recursion, a directory with recursion, and actual processing.
It does not call the input handler directly or simulate a received URL in product code.

Prepare the three original fixture copies in `.validation/finder-drop` before the test.
Open the local app with Korean UI, Korean source, translation off, and installed Apple Speech or Nemotron.
Keep the test Finder window open. The test moves only that window and the app window.
The current test host uses the DELL C3422WE monitor for side-by-side placement.
XCTest can request macOS UI automation permission.

For future investigation, run this optional test from the project root:

```sh
Scripts/run-finder-ui-tests.sh
```

The result bundle remains under `docs/evidence`. The build directory remains under `.cache`.
Xcode can create its normal developer-tool state outside this project.
The build result is in `docs/evidence/finder-ui-build.log`. No successful drag is claimed. Read `docs/evidence/finder-ui-result.json` for the recorded failure.

API source: [Apple native drag method](https://developer.apple.com/documentation/xcuiautomation/xcuielement/click%28forduration%3Athendragto%3A%29).
