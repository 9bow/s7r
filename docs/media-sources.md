# Media sources

The four short test recordings use original sentences written for this project.
The installed macOS voices generated the audio locally. No third-party recording was downloaded or redistributed.
Generated audio stays in the ignored `.validation` directory.
The scripts do not grant a new license to Apple's voices or generated speech.

| Language | Installed voice | Reference |
| --- | --- | --- |
| English | Samantha | Hello. This is a local subtitle test. The meeting starts at nine tomorrow. |
| Korean | Yuna (Korean (South Korea)) | 안녕하세요. 이것은 로컬 자막 테스트입니다. 내일 회의는 아홉 시에 시작합니다. |
| Japanese | Kyoko | こんにちは。これは字幕のテストです。明日の会議は九時に始まります。 |
| Mandarin | Tingting | 你好。这是本地字幕测试。明天的会议九点开始。 |

`Scripts/make-speech-fixtures.sh` records the exact voice names and speech rate of 160.
`Scripts/make-fixtures.swift` creates WAV, M4A, MOV, MP4, silence, corrupt data, and an audio-free video.
`Scripts/make-playback.swift` extends the video to observe subtitle clearing.
`Scripts/make-timed-playback.swift` adds a visible time counter at ten frames per second.
`Scripts/make-long.swift` repeats the English recording 300 times in an 1803-second file.
Speech starts at `3 + 6n` seconds in that long fixture.

The macOS encoder could not create MP3. The explicitly approved portable VLC created the MP3 fixture from the same English audio.
VLC 3.0.24 arm64 came from the official VideoLAN download server.
The downloaded image SHA-256 was `64a89d93cdd30b0e97131743e246373db82d6826ea882d265d46d74b136da2b7`.
VLC is a validation tool, not an application dependency or a distributed component of s7r.
The product uses AVFoundation and does not require FFmpeg or VLC.

Synthetic recordings establish repeatability and known reference text. They do not represent noisy meetings or unseen human speakers.
The reference normalization removes case, punctuation, and whitespace. It also equates each language's written form of nine with the digit 9.
The comparison keeps the unmodified hypotheses and timestamps in JSON.
The initial English-only numeral normalization was corrected before the final model comparison.
