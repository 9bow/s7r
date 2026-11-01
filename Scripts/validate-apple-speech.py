#!/usr/bin/env python3
"""Exercise installed Apple Speech assets with local, original fixtures."""
import json
import signal
import subprocess
import time
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / '.build/out/Products/Debug/s7r'
EVIDENCE = ROOT / 'docs/evidence/apple-speech'
EVIDENCE.mkdir(parents=True, exist_ok=True)
references = json.loads((ROOT / 'docs/evidence/real-validation.json').read_text())['asr']
record = {}

def normalize(text, language):
    text = unicodedata.normalize('NFC', text).lower().replace({'en': 'nine', 'ko': '아홉', 'ja': '九', 'zh': '九'}[language], '9')
    return ''.join(c for c in text if unicodedata.category(c)[0] not in 'PZS')

def distance(left, right):
    row = list(range(len(right) + 1))
    for index, a in enumerate(left, 1):
        next_row = [index]
        for column, b in enumerate(right, 1):
            next_row.append(min(next_row[-1] + 1, row[column] + 1, row[column - 1] + (a != b)))
        row = next_row
    return row[-1]

def run(name, language, media, extra=()):
    start = time.monotonic()
    result = subprocess.run([str(BIN), 'transcribe', '--asr', 'apple', '--source', language, '--format', 'json,srt,txt', '--overwrite', '--output', str(ROOT / '.validation/apple-speech' / name), str(media), *extra], cwd=ROOT, capture_output=True, timeout=120)
    (EVIDENCE / f'{name}-stdout.json').write_bytes(result.stdout)
    (EVIDENCE / f'{name}-stderr.jsonl').write_bytes(result.stderr)
    assert result.returncode == 0, result.stderr.decode()
    summary = json.loads(result.stdout)
    job = summary['jobs'][0]
    transcript = json.loads(Path(next(p for p in job['outputs'] if p.endswith('.json'))).read_text())
    previous = 0
    for segment in transcript['segments']:
        assert previous <= segment['start'] < segment['end'] <= transcript['duration'] + .001
        previous = segment['end']
        assert segment.get('words')
        for word in segment['words']:
            assert 0 <= word['start'] < word['end'] <= transcript['duration'] + .001
    record[name] = {'exitCode': result.returncode, 'seconds': round(time.monotonic() - start, 3), 'summary': summary, 'transcript': transcript}
    print(name, record[name]['seconds'], ''.join(s['source'] for s in transcript['segments']), flush=True)
    return transcript

for language, filename in [('ko', '한국어 예제.aiff'), ('en', 'English sample.aiff'), ('ja', '日本語 sample.aiff'), ('zh', '中文 sample.aiff')]:
    transcript = run(language, language, ROOT / '.validation/media' / filename)
    reference = normalize(references[language]['reference'], language)
    hypothesis = normalize(''.join(s['source'] for s in transcript['segments']), language)
    record[language]['normalizedCharacterErrorRate'] = distance(reference, hypothesis) / len(reference)
    record[language]['reference'] = references[language]['reference']
    assert record[language]['normalizedCharacterErrorRate'] <= .05
video = run('offset', 'en', ROOT / '.validation/media/offset video.mp4')
assert 2.9 <= video['segments'][0]['start'] <= 3.6
assert 'tomorrow' in ''.join(s['source'] for s in video['segments']).lower()
silence = run('silence', 'en', ROOT / '.validation/media/silence.wav')
assert not silence['segments']
run('keywords', 'ko', ROOT / '.validation/media/한국어 예제.aiff', ['--keywords-file', str(ROOT / 'docs/evidence/vocabulary.txt')])
with (EVIDENCE / 'cancel-stderr.jsonl').open('wb') as error_log, (EVIDENCE / 'cancel-stdout.json').open('wb') as output:
    process = subprocess.Popen([str(BIN), 'transcribe', '--asr', 'apple', '--source', 'en', '--output', str(ROOT / '.validation/apple-speech/cancel'), str(ROOT / '.validation/long-30min.caf')], cwd=ROOT, stdout=output, stderr=error_log)
    deadline = time.monotonic() + 60
    while 'transcribing' not in (EVIDENCE / 'cancel-stderr.jsonl').read_text():
        assert process.poll() is None
        assert time.monotonic() < deadline
        time.sleep(.02)
    start = time.monotonic()
    process.send_signal(signal.SIGINT)
    exit_code = process.wait(timeout=15)
    assert exit_code == 130
    record['cancellation'] = {'exitCode': exit_code, 'seconds': round(time.monotonic() - start, 3)}
(EVIDENCE / 'real-validation.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print('Apple Speech acceptance passed.', flush=True)
