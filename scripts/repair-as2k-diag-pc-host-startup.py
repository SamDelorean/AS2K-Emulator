#!/usr/bin/env python3
"""Repair one proven AS2K-DIAG init-order bug in its already-patched driver.

This is NOT a stable/AS2K UI patch and does not touch debugger or AGENTS.md.
Exact old SHA, exact source line and backups are required.
"""
import argparse
import hashlib
import os
import subprocess
import sys
from pathlib import Path

PREVIOUS_SHA256 = "c83b6dd3f528827851680b8333a1e087be31dce956bddd98d6dea734fdb0a832"
EXPECTED_HEAD = "a4b99b1a700a1d70b93a798fe7833e4cae28c137"
OLD = b"    m_diag_pc_last = BIT(m_diag_pc->read(), 0);"
NEW = b"    m_diag_pc_last = false;"

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--driver",type=Path,required=True)
    ap.add_argument("--backup",type=Path,required=True)
    a=ap.parse_args()
    p=a.driver.absolute()
    if p.is_symlink() or p.name!="alphasma.cpp" or p.parent.name!="skeleton" or p.parent.parent.name!="mame":
        raise ValueError("must be regular canonical DIAG driver file")
    repo=p.parents[3]
    if p.relative_to(repo).as_posix()!="src/mame/skeleton/alphasma.cpp":
        raise ValueError("wrong driver location")
    head=subprocess.check_output(["git","-C",str(repo),"rev-parse","HEAD"],text=True).strip()
    if head!=EXPECTED_HEAD:
        raise ValueError("unexpected canonical DIAG source HEAD")
    old=p.read_bytes()
    digest=hashlib.sha256(old).hexdigest()
    if digest!=PREVIOUS_SHA256 or old.count(OLD)!=1 or b"AS2K_DIAG_PC_HOST_EDGE_WAKE_IRQ" not in old:
        raise ValueError("source SHA or exact crash anchor differs: refuse to overwrite")
    if a.backup.exists() or a.backup.is_symlink():
        raise ValueError("repair backup path already exists")
    a.backup.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    a.backup.write_bytes(old)
    new=old.replace(OLD,NEW)
    tmp=p.with_name("alphasma.cpp.as2k-pc-host-initfix.tmp")
    if tmp.exists() or tmp.is_symlink():
        raise ValueError("repair temporary file already exists")
    try:
        tmp.write_bytes(new)
        os.chmod(tmp, p.stat().st_mode & 0o777)
        os.replace(tmp,p)
    finally:
        if tmp.exists(): tmp.unlink()
    print("AS2K_DIAG_INIT_ORDER_REPAIRED",digest,"->",hashlib.sha256(new).hexdigest())
    print("AS2K_DIAG_INITIAL_PC_STATE_LOW; INPUTS_READ_ONLY_AFTER_INIT")
if __name__=="__main__":
    try:main()
    except (OSError, ValueError, subprocess.CalledProcessError) as e:
        print("BLOCKED_AS2K_DIAG_INIT_REPAIR:",str(e),file=sys.stderr)
        raise SystemExit(4)
