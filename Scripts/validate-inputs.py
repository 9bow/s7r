#!/usr/bin/env python3
import json,os,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BIN=ROOT/'.build/out/Products/Debug/s7r'
EVIDENCE=ROOT/'docs/evidence'
folder=ROOT/'.validation/input-directory'
(folder/'sub').mkdir(parents=True,exist_ok=True)
shutil.copyfile(ROOT/'.validation/media/audio sample.wav',folder/'audio.wav')
shutil.copyfile(ROOT/'.validation/media/broken.mp4',folder/'broken.mp4')
shutil.copyfile(ROOT/'.validation/media/offset video.mp4',folder/'sub/video.mp4')
report={}
for recursive in [False,True]:
    arguments=['transcribe','--source','en','--format','json','--output','.validation/directory-output']
    if recursive:arguments+=['--recursive']
    arguments+=[str(folder),str(folder/'audio.wav')]
    result=subprocess.run([str(BIN)]+arguments,cwd=ROOT,capture_output=True,timeout=120)
    summary=json.loads(result.stdout)
    assert len(summary['jobs'])==(3 if recursive else 2)
    assert summary['succeeded']==(2 if recursive else 1) and summary['failed']==1
    report['recursive' if recursive else 'nonrecursive']=summary
for name,args,expected in [
 ('unknown-option',['--bad-option'],2),
 ('invalid-width',['transcribe','--line-length','0','anything.wav'],2),
 ('nemotron-auto',['transcribe','--source','auto','anything.wav'],2),
 ('missing-model',['transcribe','--models',str(ROOT/'.validation/missing-models'),str(ROOT/'.validation/media/audio sample.wav')],1),
 ('apple-missing-assets',['transcribe','--asr','apple','--source','en',str(ROOT/'.validation/media/audio sample.wav')],1)]:
    result=subprocess.run([str(BIN)]+args,cwd=ROOT,capture_output=True,timeout=30)
    assert result.returncode==expected,(name,result.returncode)
    report[name]={'exitCode':result.returncode,'stdout':result.stdout.decode(),'stderr':result.stderr.decode()}
(EVIDENCE/'input-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print({key:(value.get('exitCode') if 'exitCode' in value else len(value['jobs'])) for key,value in report.items()})
