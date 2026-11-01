#!/usr/bin/env python3
"""Exercise the extracted release with the original build resources unavailable."""
import json
import os
import subprocess
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / 'VERSION').read_text().strip()
NAME = f's7r-{VERSION}-macos-arm64'
WORK = ROOT / '.cache/release-smoke' / str(uuid.uuid4())
WORK.mkdir(parents=True)
EVIDENCE = ROOT / f'docs/evidence/release-{VERSION}'
EVIDENCE.mkdir(parents=True, exist_ok=True)
subprocess.run(['ditto', '-x', '-k', str(ROOT / 'dist' / (NAME + '.zip')), str(WORK)], check=True)
CLI = WORK / NAME / 'cli/s7r'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(WORK / NAME / 's7r.app')], check=True)
environment = dict(os.environ)
environment.pop('DYLD_FRAMEWORK_PATH', None)
record = {'version': VERSION, 'originalBuildResourcesHidden': True, 'cases': {}}
renamed = []
try:
    for bundle in (ROOT / '.build/out/Products/Release').glob('*.bundle'):
        backup = bundle.with_name(bundle.name + '.release-smoke-backup')
        assert not backup.exists()
        bundle.rename(backup)
        renamed.append((bundle, backup))
    cases = {
        'help': ['--help'],
        'status': ['status', '--models', str(ROOT / 'Models')],
        'nemotron': ['transcribe', '--asr', 'nemotron', '--source', 'ko', '--models', str(ROOT / 'Models'), '--format', 'srt,json', '--output', str(WORK / 'nemotron-output'), str(ROOT / '.validation/media/한국어 예제.aiff')],
        'whisper': ['transcribe', '--asr', 'whisper', '--source', 'auto', '--models', str(ROOT / 'Models'), '--format', 'srt,json', '--output', str(WORK / 'whisper-output'), str(ROOT / '.validation/media/English sample.aiff')],
        'qwen': ['translate-text', '--source', 'en', '--target', 'ko', '--translator', 'qwen', '--models', str(ROOT / 'Models'), 'Hello. The meeting starts at nine tomorrow.'],
    }
    for name, arguments in cases.items():
        start = time.monotonic()
        result = subprocess.run([str(CLI), *arguments], cwd=WORK, env=environment, capture_output=True, timeout=180)
        (EVIDENCE / f'{name}-stdout.txt').write_bytes(result.stdout)
        (EVIDENCE / f'{name}-stderr.txt').write_bytes(result.stderr)
        assert result.returncode == 0, (name, result.returncode, result.stderr.decode(errors='replace'))
        entry = {'exitCode': result.returncode, 'seconds': round(time.monotonic() - start, 3)}
        if name != 'help':
            entry['result'] = json.loads(result.stdout)
        if name in ['nemotron', 'whisper']:
            job = entry['result']['jobs'][0]
            assert job['state'] == 'succeeded'
            transcript = json.loads(Path(next(p for p in job['outputs'] if p.endswith('.json'))).read_text())
            assert transcript['segments']
            entry['transcript'] = transcript
        if name == 'qwen':
            assert entry['result']['translation'].strip()
        record['cases'][name] = entry
        print(name, entry['exitCode'], entry['seconds'], flush=True)
finally:
    for bundle, backup in reversed(renamed):
        backup.rename(bundle)
record['allPassed'] = True
(EVIDENCE / 'validation.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print('Extracted release passed with original build resource bundles hidden.', flush=True)
