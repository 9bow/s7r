#!/usr/bin/env python3
import json
import urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
models=[]
for identifier,repo,directory,license in [
    ('nemotron','mlx-community/nemotron-3.5-asr-streaming-0.6b-8bit','nemotron-0.6b','OpenMDW-1.1'),
    ('qwen-asr','mlx-community/Qwen3-ASR-1.7B-4bit','qwen-asr-1.7b','Apache-2.0'),
    ('qwen-aligner','mlx-community/Qwen3-ForcedAligner-0.6B-4bit','qwen-aligner-0.6b','Apache-2.0')]:
    with urllib.request.urlopen('https://huggingface.co/api/models/'+repo+'?blobs=true') as response: info=json.load(response)
    revision=info['sha']
    files=[dict(path=directory+'/'+item['rfilename'],url=f"https://huggingface.co/{repo}/resolve/{revision}/{item['rfilename']}",bytes=item['size'],sha256=item.get('lfs',{}).get('sha256')) for item in info['siblings'] if item['rfilename'] not in ['README.md','.gitattributes']]
    models.append(dict(id=identifier,name=repo,revision=revision,license=license,downloadBytes=sum(f['bytes'] for f in files),files=files))
(ROOT/'Benchmarks/models.json').write_text(json.dumps(models,indent=2)+'\n')
print([(m['id'],m['downloadBytes']) for m in models])
