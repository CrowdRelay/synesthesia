#!/usr/bin/env python3
from __future__ import annotations
import argparse,json
from pathlib import Path
RULES={'totalBytes':(1.15,2*1024*1024),'pckBytes':(1.15,1*1024*1024),'wasmBytes':(1.15,256*1024),'largestWasmBytes':(1.15,128*1024),'fileCount':(1.25,5)}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('current',type=Path);ap.add_argument('previous',type=Path);a=ap.parse_args();c=json.loads(a.current.read_text());p=json.loads(a.previous.read_text());bad=[]
 for k,(ratio,noise) in RULES.items():
  cur=float(c[k]); prev=float(p[k]); limit=max(prev*ratio,prev+noise)
  if cur>limit: bad.append(f'{k}:{cur:g}>{limit:g}(prev={prev:g})')
 if bad: raise SystemExit('SYNESTHESIA_WEB_REGRESSION=FAIL '+','.join(bad))
 print('SYNESTHESIA_WEB_REGRESSION=PASS baseline=previous-successful-main')
if __name__=='__main__': main()
