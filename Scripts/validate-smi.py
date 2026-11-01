#!/usr/bin/env python3
"""Render exported subtitles through an explicitly installed local VLC."""
from pathlib import Path
import argparse
import subprocess
parser=argparse.ArgumentParser()
parser.add_argument('--format',choices=['smi','srt'],default='smi')
args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1]
output=ROOT/f'.validation/vlc-{args.format}-frames.pngstream'
if output.exists():output.unlink()
sout="#transcode{vcodec=png,width=1280,height=720,fps=1,soverlay}:std{access=file,mux=raw,dst='"+str(output)+"'}"
command=[str(ROOT/'.cache/VLC.app/Contents/MacOS/VLC'),'--intf','dummy','--codec','avcodec','--avcodec-hw','none','--no-media-library','--no-sout-audio','--no-metadata-network-access','--play-and-exit','--sub-file',str(ROOT/f'.validation/timed-subtitles/timed playback.{args.format}'),'--sout',sout,str(ROOT/'.validation/media/timed playback.mp4')]
with (ROOT/f'.cache/vlc-{args.format}-render.log').open('wb') as log:
    result=subprocess.run(command,stdout=log,stderr=log,timeout=90)
assert result.returncode==0,(result.returncode,(ROOT/f'.cache/vlc-{args.format}-render.log').read_text())
assert output.exists() and output.stat().st_size>10_000
print('VLC',args.format.upper(),'render bytes:',output.stat().st_size)

data=output.read_bytes()
frames=[]
position=0
signature=b"\x89PNG\r\n\x1a\n"
while position<len(data):
    start=data.find(signature,position)
    if start<0:break
    cursor=start+8
    while cursor+12<=len(data):
        size=int.from_bytes(data[cursor:cursor+4],'big')
        kind=data[cursor+4:cursor+8]
        cursor+=size+12
        if kind==b'IEND':break
    frames.append(data[start:cursor]);position=cursor
assert len(frames)>=11,len(frames)
for second in [2,5,7,10]:
    (ROOT/f'docs/evidence/vlc-{args.format}-frame-{second:02}.png').write_bytes(frames[second])
print('VLC PNG frames:',len(frames))
