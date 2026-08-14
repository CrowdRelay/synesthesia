#!/usr/bin/env python3
from __future__ import annotations
import argparse,json
from pathlib import Path

def main():
 ap=argparse.ArgumentParser(); ap.add_argument('root',type=Path); ap.add_argument('output',type=Path); a=ap.parse_args()
 files=[p for p in a.root.rglob('*') if p.is_file()]; pcks=[p for p in files if p.suffix=='.pck']; wasm=[p for p in files if p.suffix=='.wasm']
 if not pcks or not wasm: raise SystemExit('expected Web PCK and WASM artifacts')
 data={'schema':1,'fileCount':len(files),'totalBytes':sum(p.stat().st_size for p in files),'pckBytes':sum(p.stat().st_size for p in pcks),'wasmBytes':sum(p.stat().st_size for p in wasm),'largestWasmBytes':max(p.stat().st_size for p in wasm)}
 a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_text(json.dumps(data,indent=2,sort_keys=True)+'\n')
 print('SYNESTHESIA_WEB_METRICS=PASS '+' '.join(f'{k}={v}' for k,v in data.items() if k!='schema'))
if __name__=='__main__': main()
