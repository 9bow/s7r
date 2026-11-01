#!/usr/bin/env python3
"""Measure a local 30-minute transcription with bounded PCM windows."""
import json
import argparse
import os
import signal
import subprocess
import time
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--engine', choices=['whisper','nemotron'], default='whisper')
args=parser.parse_args()
prefix='long' if args.engine=='whisper' else 'long-nemotron'
ROOT=Path(__file__).resolve().parents[1]
BIN=ROOT/'.build/out/Products/Debug/s7r'
ENV=dict(os.environ,DYLD_FRAMEWORK_PATH=str(BIN.parent))
EVIDENCE=ROOT/'docs/evidence'
with (EVIDENCE/(prefix+'-progress.jsonl')).open('wb') as log, (EVIDENCE/(prefix+'-summary.json')).open('wb') as output:
    start=time.monotonic()
    process=subprocess.Popen([str(BIN),'transcribe','--asr',args.engine,'--source','en','--format','json,srt','--overwrite','--output','.validation/'+prefix+'-output','.validation/long-30min.caf'],cwd=ROOT,env=ENV,stdout=output,stderr=log)
    memory=[]
    while process.poll() is None:
        snapshot=subprocess.run(['ps','-o','rss=','-p',str(process.pid)],capture_output=True,text=True)
        if snapshot.stdout.strip(): memory.append({'seconds':round(time.monotonic()-start,2),'rssBytes':int(snapshot.stdout.strip())*1024})
        if time.monotonic()-start>1800:
            process.send_signal(signal.SIGINT)
            break
        time.sleep(1)
    code=process.wait(timeout=20)
record={'exitCode':code,'seconds':round(time.monotonic()-start,3),'peakRSSBytes':max((item['rssBytes'] for item in memory),default=0),'samples':memory}
output=ROOT/('.validation/'+prefix+'-output/long-30min.json')
if output.exists():
    transcript=json.loads(output.read_text())
    segments=transcript['segments']
    record.update(duration=transcript['duration'],segmentCount=len(segments),first=segments[:2],middle=[s for s in segments if 897<=s['start']<=905],last=segments[-2:])
(EVIDENCE/(prefix+'-metrics.json')).write_text(json.dumps(record,indent=2)+'\n')
print({k:v for k,v in record.items() if k not in ['samples','first','middle','last']},flush=True)
