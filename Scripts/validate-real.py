#!/usr/bin/env python3
"""Run local engines against original synthetic fixtures. No model download occurs."""
import json
import argparse
import os
import re
import subprocess
import time
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / '.build/out/Products/Debug/s7r'
EVIDENCE = ROOT / 'docs/evidence'
ENV = dict(os.environ, DYLD_FRAMEWORK_PATH=str(BIN.parent))
CASES = {
    'en': ('English sample.aiff', 'Hello. This is a local subtitle test. The meeting starts at nine tomorrow.', 'Samantha'),
    'ko': ('한국어 예제.aiff', '안녕하세요. 이것은 로컬 자막 테스트입니다. 내일 회의는 아홉 시에 시작합니다.', 'Yuna (Korean (South Korea))'),
    'ja': ('日本語 sample.aiff', 'こんにちは。これは字幕のテストです。明日の会議は九時に始まります。', 'Kyoko'),
    'zh': ('中文 sample.aiff', '你好。这是本地字幕测试。明天的会议九点开始。', 'Tingting'),
}

def run(name, arguments, timeout=240):
    start = time.monotonic()
    result = subprocess.run([str(BIN)] + arguments, cwd=ROOT, env=ENV, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    (EVIDENCE / (name + '-stdout.json')).write_bytes(result.stdout)
    (EVIDENCE / (name + '-stderr.jsonl')).write_bytes(result.stderr)
    value = {'exitCode': result.returncode, 'seconds': round(time.monotonic() - start, 3)}
    try:
        value['result'] = json.loads(result.stdout)
    except (ValueError, UnicodeDecodeError):
        value['error'] = 'stdout is not JSON'
    return value

def normalized(text, language):
    text = unicodedata.normalize('NFC', text).lower()
    numeral = {'en': 'nine', 'ko': '아홉', 'ja': '九', 'zh': '九'}[language]
    text = text.replace(numeral, '9')
    return ''.join(c for c in text if unicodedata.category(c)[0] not in 'PZS')

def distance(a, b):
    row = list(range(len(b) + 1))
    for index, left in enumerate(a, 1):
        next_row = [index]
        for column, right in enumerate(b, 1):
            next_row.append(min(next_row[-1] + 1, row[column] + 1, row[column-1] + (left != right)))
        row = next_row
    return row[-1]

parser = argparse.ArgumentParser()
parser.add_argument('--qwen-only', action='store_true')
arguments = parser.parse_args()
record = json.loads((EVIDENCE / 'real-validation.json').read_text()) if arguments.qwen_only else {'asr': {}, 'translation': {}, 'media': {}}
for language, (filename, reference, voice) in ({} if arguments.qwen_only else CASES).items():
    result = run('asr-' + language, ['transcribe', '--asr', 'whisper', '--source', language, '--format', 'json,srt,smi,txt', '--overwrite', '--output', '.validation/real-' + language, str(ROOT / '.validation/media' / filename)])
    if result.get('result', {}).get('jobs', [{}])[0].get('state') == 'succeeded':
        outputs = result['result']['jobs'][0]['outputs']
        transcript = json.loads(Path(next(path for path in outputs if path.endswith('.json'))).read_text())
        hypothesis = ''.join(segment['source'] for segment in transcript['segments'])
        reference_normalized = normalized(reference, language)
        result.update(reference=reference, hypothesis=hypothesis, normalizedCharacterErrorRate=distance(reference_normalized, normalized(hypothesis, language)) / len(reference_normalized), segments=transcript['segments'])
        (EVIDENCE / ('asr-' + language + '-transcript.json')).write_text(json.dumps(transcript, ensure_ascii=False, indent=2) + '\n')
    record['asr'][language] = result
    print('ASR', language, result['exitCode'], result.get('hypothesis'), flush=True)
    (EVIDENCE / 'real-validation.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
for engine in (['qwen'] if arguments.qwen_only else ['apple', 'qwen']):
    record['translation'][engine] = {}
    for source, (_, text, _) in CASES.items():
        for target in CASES:
            if source == target:
                continue
            result = run('translation-' + engine + '-' + source + '-' + target, ['translate-text', '--source', source, '--target', target, '--translator', engine, text])
            record['translation'][engine][source + '>' + target] = result
            print('Translation', engine, source, target, result['exitCode'], result.get('result', {}).get('translation'), flush=True)
            (EVIDENCE / 'real-validation.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
for filename in ([] if arguments.qwen_only else ['audio sample.wav', 'audio sample.m4a', 'offset video.mp4', 'offset video.mov', 'silence.wav', 'no audio.mov', 'broken.mp4']):
    result = run('media-' + filename.replace(' ', '-'), ['transcribe', '--asr', 'whisper', '--source', 'en', '--format', 'json,srt', '--overwrite', '--output', '.validation/formats', str(ROOT / '.validation/media' / filename)])
    record['media'][filename] = result
    print('Media', filename, result['exitCode'], flush=True)
    (EVIDENCE / 'real-validation.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
