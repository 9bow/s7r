#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / '.build/out/Products/Debug/s7r'
IDENTITY = ['translate-text', '--source', 'en', '--target', 'en', '--translator', 'qwen']
report = {}


def run(name, arguments, expected=0):
    result = subprocess.run([str(BIN), *arguments], cwd=ROOT, capture_output=True, text=True, timeout=20)
    assert result.returncode == expected, (name, result.returncode, result.stdout, result.stderr)
    report[name] = {'exitCode': result.returncode}
    return result


with tempfile.TemporaryDirectory(prefix='s7r-cli-options-', dir='/private/tmp') as temporary:
    folder = Path(temporary)
    for name, text in [('literal-help', '--help'), ('literal-short-help', '-h'),
                       ('literal-config', '--config missing.json'), ('literal-separator', '--')]:
        result = run(name, [*IDENTITY, '--', *text.split()])
        assert json.loads(result.stdout) == {'source': text, 'translation': text}

    saved = folder / 'saved.json'
    result = run('option-values', [*IDENTITY, '--asr', 'whisper', '--keywords', '--help',
                                  '--models', '--config', '--save-config', str(saved), 'hello'])
    configuration = json.loads(saved.read_text())
    assert configuration['keywords'] == ['--help']
    assert configuration['modelDirectory'] == '--config'
    assert json.loads(result.stdout)['translation'] == 'hello'

    configuration['keywords'] = ['saved keyword']
    configuration['lineLength'] = 12
    configuration['recursive'] = True
    configuration['overwrite'] = True
    source = folder / 'configuration.json'
    source.write_text(json.dumps(configuration))
    vocabulary = folder / 'vocabulary.txt'
    vocabulary.write_text('file keyword\nCLI keyword\n', encoding='utf-8')
    for name, options, keywords in [
        ('saved-keywords', [], ['saved keyword']),
        ('replace-keywords', ['--keywords', 'CLI keyword', '--keywords-file', str(vocabulary)],
         ['CLI keyword', 'file keyword']),
        ('clear-keywords', ['--keywords', ''], []),
    ]:
        run(name, [*IDENTITY, '--line-length', '24', *options, '--no-recursive', '--no-overwrite',
                   '--config', str(source), '--save-config', str(saved), 'hello'])
        resolved = json.loads(saved.read_text())
        assert resolved['keywords'] == keywords
        assert resolved['lineLength'] == 24
        assert not resolved['recursive'] and not resolved['overwrite']

    result = run('help', ['transcribe', '--help'])
    assert 'Usage:' in result.stdout and not result.stderr
    run('missing-value', ['transcribe', '--config'], 2)
    run('unknown-option', ['transcribe', '--bad-option'], 2)

(ROOT / 'docs/evidence/cli-options-validation.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'{len(report)} CLI option cases passed.')
