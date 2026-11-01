# Player validation

## Recorded result

The official VLC 3.0.24 arm64 renderer loaded the exported SRT and SAMI files through `--sub-file`.
Both formats showed the English source and Korean translation together.
The Korean glyphs rendered correctly. No replacement boxes appeared in the inspected frames.
The final cue disappeared after its clear event.

The test used the video from `Scripts/make-timed-playback.swift`.
Its source frames contain a visible clock at ten frames per second. Audio starts at three seconds.
The original 320 by 180 video was scaled to 1280 by 720 for inspection.

| Visible source clock | Expected state | SMI evidence | SRT evidence |
| --- | --- | --- | --- |
| 1.1 seconds | No caption | [Frame](evidence/vlc-smi-frame-02.png) | [Frame](evidence/vlc-srt-frame-02.png) |
| 4.1 seconds | First bilingual cue | [Frame](evidence/vlc-smi-frame-05.png) | [Frame](evidence/vlc-srt-frame-05.png) |
| 6.1 seconds | Second bilingual cue | [Frame](evidence/vlc-smi-frame-07.png) | [Frame](evidence/vlc-srt-frame-07.png) |
| 9.1 seconds | No caption | [Frame](evidence/vlc-smi-frame-10.png) | [Frame](evidence/vlc-srt-frame-10.png) |

The file index does not represent the source clock. Read the clock printed inside each frame.
The SAMI event times were 3360, 6000, and 7920 milliseconds.
The last event clears the screen. Adjacent cues use one event at their shared boundary.
SAMI uses one language class for simultaneous bilingual text, rather than separate selectable language tracks.

## Method and limits

VLC rendered subtitle overlays into a stream of PNG images through its headless interface.
`Scripts/validate-smi.py` extracted complete PNG records from that stream.
The test used the real VLC subtitle parser and renderer. It did not manually draw text onto screenshots.
The product itself does not re-encode video or burn in captions.

The native VLC GUI could not expose a usable window through the automation interface.
This record establishes renderer compatibility, not an observed interactive playback session.
IINA and other subtitle players were not tested. Separate language-track selection was not tested.

After the timed video and exported subtitles exist, reproduce the render from the project root:

```sh
python3 Scripts/validate-smi.py --format smi
python3 Scripts/validate-smi.py --format srt
python3 Scripts/validate-exports.py
```

The render script requires the approved portable app at `.cache/VLC.app`.
Read [media sources](media-sources.md) for the official download and image hash.
