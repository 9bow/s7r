# Apple Speech execution

## Recorded result

On November 1, 2026, all four explicit installation commands completed and the CLI reported installed assets for ko, en, ja, and zh.
Apple manages the files outside this project. The API does not report download bytes or whether it reuses cached files.
The commands completed in less than one second each. This does not prove a new network download.

The real model processed the same four original synthetic recordings as the other engines.
The reference comparison uses the normalization from the existing ASR comparison.
It removes punctuation, spaces, and case, and equates each written numeral nine with 9.
The fixture criterion requires less than 5% normalized character error and valid file-relative times.

| Language | Normalized character error | Full CLI process time |
| --- | ---: | ---: |
| Korean | 0% | 0.820 seconds |
| English | 1.79% | 0.519 seconds |
| Japanese | 0% | 0.530 seconds |
| Mandarin | 0% | 0.530 seconds |

English contains one extra character: subtitle became subtitled.
Mandarin punctuation does not fully preserve the sentence breaks. The normalized metric excludes that difference.
These short synthetic examples do not establish accuracy on natural conversations, noise, accents, or proper names.
Process times include the CLI launch and decoding. They do not establish a controlled speed ranking across engines.

Every returned segment and word has a nonnegative start and a positive duration.
Segment order has no overlap. Times remain within the file duration.
The video with a three-second audio offset produced its first segment at 3.00 seconds.
Its final sentence remains in the output, with the last segment ending at 7.74 seconds.
Silence produced no segments. A real keyword-file run completed with two contextual hints.
That Korean reference was already correct without hints, so no accuracy gain is claimed.
Cancellation of the long-file job returned code 130 in about 0.071 seconds after the signal.
A completed long Apple Speech run was not part of this test.

Read [the raw transcripts and metrics](evidence/apple-speech/real-validation.json), [installation results](evidence/apple-speech/installation.json), and [current capability status](evidence/apple-speech/status.json).

## GUI result

The GUI initially reported missing Korean assets after the CLI preparation succeeded.
The explicit speech asset preparation button then completed and the GUI reported installed status.
A retry completed one Korean file, generated SRT and JSON, and showed the SRT preview.
The GUI source segments and word times equal the CLI result. The SRT bytes also match.
Read [the GUI comparison](evidence/apple-speech/gui-validation.json).

If the GUI still reports missing assets after CLI preparation, use the explicit preparation button inside that app.
This record does not assume that asset readiness transfers between every process or application identity.
The GUI test used the file dialog. It does not count as a Finder drag test.

## Reproduce

Run the installation commands only when you select Apple Speech asset preparation:

```sh
.build/out/Products/Debug/s7r install-speech --source ko
.build/out/Products/Debug/s7r install-speech --source en
.build/out/Products/Debug/s7r install-speech --source ja
.build/out/Products/Debug/s7r install-speech --source zh
```

After the original fixtures and installed assets are ready, run the local test:

```sh
python3 Scripts/validate-apple-speech.py
```

The test requires normal access to local macOS media and speech services.
It writes results under `.validation/apple-speech` and evidence under `docs/evidence/apple-speech`.
It does not start a model download or send the media to an external inference service.
