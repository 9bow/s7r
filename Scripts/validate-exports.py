#!/usr/bin/env python3
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
record=[]
for directory in ['.validation/timed-subtitles','.validation/chinese-traditional']:
 for transcript_file in (ROOT/directory).glob('*.json'):
  transcript=json.loads(transcript_file.read_text(encoding='utf-8'))
  segments=transcript['segments']
  assert len({s['id'] for s in segments})==len(segments)
  assert all(s['start']>=0 and s['end']>s['start'] for s in segments)
  assert all(left['end']<=right['start'] for left,right in zip(segments,segments[1:]))
  srt=transcript_file.with_suffix('.srt').read_text(encoding='utf-8')
  blocks=srt.strip().split('\n\n') if srt.strip() else []
  previous=0
  def millis(text):
   hours,minutes,seconds,ms=map(int,re.split('[:,]',text));assert 0<=minutes<60 and 0<=seconds<60
   return hours*3600000+minutes*60000+seconds*1000+ms
  for index,block in enumerate(blocks,1):
   lines=block.splitlines();assert lines[0]==str(index)
   match=re.fullmatch(r'(\d{2,}:\d{2}:\d{2},\d{3}) --> (\d{2,}:\d{2}:\d{2},\d{3})',lines[1]);assert match
   start,end=map(millis,match.groups());assert 0<=previous<=start<end;previous=end
   assert 1<=len(lines[2:])<=2
  smi=transcript_file.with_suffix('.smi').read_text(encoding='utf-8')
  syncs=list(map(int,re.findall(r'<SYNC Start=(\d+)>',smi)))
  assert all(a<b for a,b in zip(syncs,syncs[1:]))
  assert re.search(r'<SYNC Start=\d+><P Class=S7R>&nbsp;</P>\s*</BODY>',smi)
  assert 'charset=utf-8' in smi and 'lang:' in smi
  record.append({'transcript':str(transcript_file.relative_to(ROOT)),'segments':len(segments),'srtCues':len(blocks),'samiEvents':syncs,'passed':True})
assert record
(ROOT/'docs/evidence/export-validation.json').write_text(json.dumps(record,indent=2)+'\n')
print(record)
