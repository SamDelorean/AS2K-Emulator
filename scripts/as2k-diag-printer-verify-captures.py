#!/usr/bin/env python3
"""Second-stage visual acceptance of an existing genuine MAME-DIAG printer test.

Reads only immutable screenshots and the existing report. Never launches MAME,
rewrites the original report, changes NVRAM or makes a functional Print claim.
Uses the standard library; only the cursor may differ after PC detach.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import zlib

PNG_SIGNATURE=b"\x89PNG\r\n\x1a\n"

def png_rgb(path):
    data=path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"invalid PNG: {path.name}")
    i=8
    idat=bytearray()
    width=height=depth=color=None
    while i+12<=len(data):
        n=struct.unpack(">I",data[i:i+4])[0]
        kind=data[i+4:i+8]
        payload=data[i+8:i+8+n]
        checksum=struct.unpack(">I",data[i+8+n:i+12+n])[0]
        if zlib.crc32(kind+payload)&0xffffffff != checksum:
            raise ValueError(f"invalid PNG chunk checksum {path.name}")
        i+=12+n
        if kind==b"IHDR":
            width,height,depth,color,compress,filter_method,interlace=struct.unpack(">IIBBBBB",payload)
            if (width,height,depth,color,compress,filter_method,interlace)!=(240,36,8,2,0,0,0):
                raise ValueError("unsupported LCD PNG format: must be 240x36 RGB8")
        elif kind==b"IDAT":
            idat.extend(payload)
        elif kind==b"IEND":
            break
    raw=zlib.decompress(idat)
    stride=width*3
    if len(raw)!=height*(1+stride):
        raise ValueError("wrong PNG scanline dimensions")
    rows=[]
    previous=bytearray(stride)
    i=0
    for y in range(height):
        op=raw[i];i+=1
        encoded=raw[i:i+stride];i+=stride
        row=bytearray(stride)
        for j,v in enumerate(encoded):
            left=row[j-3] if j>=3 else 0
            up=previous[j]
            upper_left=previous[j-3] if j>=3 else 0
            if op==0: predictor=0
            elif op==1: predictor=left
            elif op==2: predictor=up
            elif op==3: predictor=(left+up)//2
            elif op==4:
                p=left+up-upper_left
                a,b,c=abs(p-left),abs(p-up),abs(p-upper_left)
                predictor=left if a<=b and a<=c else up if b<=c else upper_left
            else: raise ValueError("unknown PNG filter")
            row[j]=(v+predictor)&255
        rows.append(bytes(row))
        previous=row
    return rows

def diffs(a,b):
    changes=[]
    for y,(x,z) in enumerate(zip(a,b)):
        for col in range(240):
            j=col*3
            if x[j:j+3]!=z[j:j+3]:
                changes.append((col,y))
    return changes

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir",type=Path)
    args=parser.parse_args()
    run=args.run_dir.resolve(strict=True)
    original=json.loads((run/"report.json").read_text())
    if original.get("variant")!="AS2K-DIAG":
        raise ValueError("not canonical AS2K-DIAG evidence")
    names=["editor_before","printer_attached","printer_detached","pc_attached","pc_detached"]
    pics={}
    for n in names:
        f=run/"snap"/(n+".png")
        digest=hashlib.sha256(f.read_bytes()).hexdigest()
        if original["screenshots"][n]["sha256"]!=digest:
            raise ValueError("actual PNG checksum does not match original report "+n)
        pics[n]=png_rgb(f)
    before=pics["editor_before"]
    printer_on=diffs(before,pics["printer_attached"])
    printer_off=diffs(before,pics["printer_detached"])
    pc_on=diffs(before,pics["pc_attached"])
    pc_off=diffs(before,pics["pc_detached"])
    # AlphaSmart 2000 cursor blinks in cell 0: only top-left 5x7 may
    # differ after returning from PC. Do NOT mask any other LCD region.
    cursor_only=bool(pc_off) and all(0<=x<5 and 0<=y<7 for x,y in pc_off)
    exact_printer_ready=not printer_on and not printer_off
    irq=original.get("printer_irq_edges_exact") is True and original.get("pc_irq_edges_exact") is True
    complete=original.get("events_complete") is True and "AS2K_DIAG_HOST_NO_KEYS_INJECTED" in original.get("events",[])
    success=cursor_only and len(pc_on)>500 and exact_printer_ready and irq and complete
    result={
        "status":"PRINTER_PA0_IRQ_DYNAMIC_PASS_PC_CURSOR_TOLERANT_REGRESSION_PASS" if success else "VISUAL_ACCEPTANCE_FAIL",
        "source_original_status":original.get("status"),
        "source_original_report_sha256":hashlib.sha256((run/"report.json").read_bytes()).hexdigest(),
        "binary_sha256":original.get("binary_sha256"),
        "printer_irq_edges_exact":original.get("printer_irq_edges_exact"),
        "pc_irq_edges_exact":original.get("pc_irq_edges_exact"),
        "no_keyboard":complete,
        "printer_attached_pixels_changed":len(printer_on),
        "printer_detached_pixels_changed":len(printer_off),
        "pc_connected_pixels_changed":len(pc_on),
        "pc_return_cursor_pixels_changed":len(pc_off),
        "pc_return_differences_only_in_cursor_5x7":cursor_only,
        "original_report_not_modified":True,
        "printer_PCL_or_PDF_print_job_tested":False,
        "basis":"existing MAME screenshots, precise RGB pixel comparison, authenticated original IRQ report"
    }
    (run/"visual-review.json").write_text(json.dumps(result,indent=2)+"\n")
    print("AS2K_DIAG_PRINTER_VISUAL_REVIEW_STATUS="+result["status"])
    print("LCD_DIFF_PRINTER_ON",len(printer_on),"PRINTER_OFF",len(printer_off),"PC_ON",len(pc_on),"PC_RETURN_CURSOR_ONLY",len(pc_off))
    if not success:raise SystemExit(43)

if __name__=="__main__":main()
