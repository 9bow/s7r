#!/usr/bin/env python3
"""Compare approved local ASR candidates on the same four short fixtures."""
import json
import os
import subprocess
import time
import unicodedata
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BIN=ROOT/'Benchmarks/.build/out/Products/Debug/SpeechBench'
ENV=dict(os.environ,DYLD_FRAMEWORK_PATH=str(BIN.parent))
cases={'en':'English sample.aiff','ko':'한국어 예제.aiff','ja':'日本語 sample.aiff','zh':'中文 sample.aiff'}
report={}
for engine in ['nemotron','qwen']:
    start=time.monotonic()
    with (ROOT/f'docs/evidence/asr-bench-{engine}.json').open('wb') as output, (ROOT/f'docs/evidence/asr-bench-{engine}.log').open('wb') as log:
        process=subprocess.Popen([str(BIN),engine,str(ROOT/'Models')]+[lang+':'+str(ROOT/'.validation/media'/name) for lang,name in cases.items()],cwd=ROOT,env=ENV,stdout=output,stderr=log)
        rss=[]
        while process.poll() is None:
            snapshot=subprocess.run(['ps','-o','rss=','-p',str(process.pid)],capture_output=True,text=True)
            if snapshot.stdout.strip(): rss.append(int(snapshot.stdout.strip())*1024)
            if time.monotonic()-start>600:
                process.terminate()
                break
            time.sleep(0.5)
        code=process.wait(timeout=20)
    report[engine]={'exitCode':code,'wallSeconds':time.monotonic()-start,'peakRSSBytes':max(rss,default=0)}
    (ROOT/'docs/evidence/asr-bench-metrics.json').write_text(json.dumps(report,indent=2)+'\n')
    print(engine,report[engine],flush=True)
