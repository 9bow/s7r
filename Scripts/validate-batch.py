#!/usr/bin/env python3
import hashlib,json,os,signal,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BIN=ROOT/'.build/out/Products/Debug/s7r'
ENV=dict(os.environ,DYLD_FRAMEWORK_PATH=str(BIN.parent))
EVIDENCE=ROOT/'docs/evidence'
def run(name,args,expected):
    result=subprocess.run([str(BIN)]+args,cwd=ROOT,env=ENV,capture_output=True,timeout=180)
    (EVIDENCE/(name+'-summary.json')).write_bytes(result.stdout)
    (EVIDENCE/(name+'-progress.jsonl')).write_bytes(result.stderr)
    assert result.returncode==expected,(name,result.returncode,result.stderr.decode())
    return json.loads(result.stdout)
args=['transcribe','--asr','nemotron','--source','en','--format','srt,smi,txt,json','--output','.validation/batch', '.validation/media/audio sample.wav','.validation/media/playback demo.mp4','.validation/media/broken.mp4','.validation/media/no audio.mov']
first=run('mixed-batch',args,1)
assert first['succeeded']==2 and first['failed']==2
paths=[Path(path) for job in first['jobs'] for path in job['outputs']]
hashes={str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
second=run('collision-batch',args,1)
assert hashes=={str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
assert not set(hashes)&{path for job in second['jobs'] for path in job['outputs']}
receipt=ROOT/'Models/qwen.installed.json';hidden=ROOT/'Models/qwen.installed.validation-backup'
receipt.rename(hidden)
try:
    partial=run('translation-failure',['transcribe','--asr','nemotron','--source','en','--target','ko','--translator','qwen','--display','translated','--format','srt','--output','.validation/partial','.validation/media/English sample.aiff'],1)
    assert partial['jobs'][0]['state']=='partial'
    data=json.loads(Path(next(path for path in partial['jobs'][0]['outputs'] if path.endswith('.json'))).read_text())
    assert data['segments'] and all(s['source'] and not s.get('translation') and s.get('translationError') for s in data['segments'])
finally:
    hidden.rename(receipt)
start=time.monotonic()
with (EVIDENCE/'cancel-progress.jsonl').open('wb') as log,(EVIDENCE/'cancel-summary.json').open('wb') as output:
    task=subprocess.Popen([str(BIN),'transcribe','--asr','nemotron','--source','en','--output','.validation/cancel','.validation/long-30min.caf'],cwd=ROOT,env=ENV,stdout=output,stderr=log)
    deadline=time.monotonic()+60
    while time.monotonic()<deadline:
        if 'transcribing' in (EVIDENCE/'cancel-progress.jsonl').read_text():break
        assert task.poll() is None,'Process exited before cancellation'
        time.sleep(0.05)
    cancelled=time.monotonic();task.send_signal(signal.SIGINT);code=task.wait(timeout=12)
    elapsed=time.monotonic()-cancelled
assert code==130,code
summary=json.loads((EVIDENCE/'cancel-summary.json').read_text())
assert summary['cancelledCount']==1
record={'mixedBatch':{'success':first['succeeded'],'failed':first['failed']},'collisionPreserved':True,'translationFailurePreservedSource':True,'cancellationExitCode':code,'cancellationSeconds':elapsed}
(EVIDENCE/'batch-validation.json').write_text(json.dumps(record,indent=2)+'\n')
print(record,flush=True)
