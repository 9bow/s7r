#!/usr/bin/env python3
import json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BIN=ROOT/'.build/out/Products/Debug/s7r'
env=dict(os.environ,DYLD_FRAMEWORK_PATH=str(BIN.parent))
files={'en':'English sample.aiff','ko':'한국어 예제.aiff','ja':'日本語 sample.aiff','zh':'中文 sample.aiff'}
record={}
for language,name in files.items():
    start=time.monotonic()
    result=subprocess.run([str(BIN),'transcribe','--asr','nemotron','--source',language,'--format','json,srt','--overwrite','--output','.validation/nemotron-'+language,str(ROOT/'.validation/media'/name)],cwd=ROOT,env=env,capture_output=True,timeout=180)
    (ROOT/f'docs/evidence/nemotron-product-{language}-stdout.json').write_bytes(result.stdout)
    (ROOT/f'docs/evidence/nemotron-product-{language}-stderr.jsonl').write_bytes(result.stderr)
    item={'exitCode':result.returncode,'seconds':time.monotonic()-start,'summary':json.loads(result.stdout)}
    if result.returncode==0:
        output=next(p for p in item['summary']['jobs'][0]['outputs'] if p.endswith('.json'))
        item['transcript']=json.loads(Path(output).read_text())
    record[language]=item
    (ROOT/'docs/evidence/nemotron-product.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print(language,result.returncode,[(s['start'],s['end'],s['source']) for s in item.get('transcript',{}).get('segments',[])],flush=True)
