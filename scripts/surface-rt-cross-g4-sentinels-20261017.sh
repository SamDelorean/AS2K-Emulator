#!/usr/bin/env bash
# G4 ONLY: four independent sentinel ARMv7/musl translation units.
# Never invoke top-level MAME make, modify source/checkouts, install, or package.
set -Eeuo pipefail
umask 077
D=/home/spc/Projects/alphasmart/as2k-surface-cross
TOOL="$D/armv7-eabihf--musl--stable-2025.08-1"
SYSROOT="$D/alpine-armv7-sysroot"
AS2K="$D/work/AS2K-Emulator-vontar-b3"
MAME="$D/work/mame-as3k"
WORK="$MAME/build/as2k-surface-armv7-cross/projects/sdl/mameas2k/gmake-linux"
WRAP="$D/toolchain-wrappers"
AS2K_SHA=36996b91053969661371dc067d49026fab367a47
MAME_SHA=1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b
G0_SHA=6a78cf6a620844f6fd0e0ecbbd878791f18c251cd029d9f6cd6a1479e76276d3
EVIDENCE=googledrive:AS2K_TEMP/surface-rt/results/vontar-36996b9/preflight-g4
STATUS="$D/preflight-g4-20261017.status"
LOG="$D/preflight-g4-20261017.log"
STEP=INIT
STAGE=''
block(){ printf '[%s] BLOCKED: %s\n' "$STEP" "$*" >&2; exit 2; }
pass(){ printf '[%s] PASS: %s\n' "$STEP" "$*"; }
finish(){
  local rc=$?
  trap - EXIT
  if [ "$rc" -eq 0 ]; then
    printf 'STATUS=PASS\nG0_G3=PASS\nG4=PASS\nG5=NOT_AUTHORIZED\nAS2K=%s\nMAME=%s\nSTAGE=%s\n' "$AS2K_SHA" "$MAME_SHA" "$STAGE" > "$STATUS"
  else
    printf 'STATUS=BLOCKED\nSTEP=%s\nRC=%s\nG5=NOT_AUTHORIZED\nAS2K=%s\nMAME=%s\nSTAGE=%s\n' "$STEP" "$rc" "$AS2K_SHA" "$MAME_SHA" "$STAGE" > "$STATUS"
  fi
  { rclone mkdir "$EVIDENCE" && rclone copyto "$STATUS" "$EVIDENCE/$(basename "$STATUS")" && rclone copyto "$LOG" "$EVIDENCE/$(basename "$LOG")"; } >/dev/null 2>&1 || printf 'EVIDENCE_UPLOAD_FAIL; no build was run\n' >&2
  exit "$rc"
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$D"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

STEP=G4_0_BASELINE
for c in git python3 make timeout readelf file rclone sha256sum; do command -v "$c" >/dev/null 2>&1 || block "Missing $c"; done
[ "$(git -C "$AS2K" rev-parse HEAD)" = "$AS2K_SHA" ] || block 'AS2K SHA changed'
[ "$(git -C "$MAME" rev-parse HEAD)" = "$MAME_SHA" ] || block 'MAME SHA changed'
git -C "$AS2K" diff --quiet && git -C "$AS2K" diff --cached --quiet || block 'AS2K tracked modifications'
git -C "$MAME" diff --quiet && git -C "$MAME" diff --cached --quiet || block 'MAME tracked modifications'
[ -x "$TOOL/bin/arm-linux-g++" ] && [ -x "$WRAP/arm-cxx" ] || block 'Frozen compiler/wrapper absent'
[ -f "$D/preflight-g0-g3-20261017.status" ] || block 'Preceding preflight status absent'
grep -Fxq 'STATUS=PASS' "$D/preflight-g0-g3-20261017.status" || block 'Preceding preflight not PASS'
grep -Fxq 'GATES=G0_G1_G2_G3' "$D/preflight-g0-g3-20261017.status" || block 'Preceding gates not complete'
grep -Fxq "AS2K=$AS2K_SHA" "$D/preflight-g0-g3-20261017.status" || block 'Preceding AS2K SHA mismatch'
grep -Fxq "MAME=$MAME_SHA" "$D/preflight-g0-g3-20261017.status" || block 'Preceding MAME SHA mismatch'
STAGE_PREV=$(sed -n 's/^STAGE=//p' "$D/preflight-g0-g3-20261017.status")
case "$STAGE_PREV" in "$D"/preflight-g0-g3.*) ;; *) block 'Preflight stage path unexpected' ;; esac
[ -s "$STAGE_PREV/safe-builder.sh" ] && [ -s "$STAGE_PREV/overrides/bx/platform.h" ] || block 'Preflight vetted overlay artifacts missing'
[ -f "$WORK/Makefile" ] || block 'Generated MAME makefiles missing'
for name in emu bx osd_sdl; do [ -f "$WORK/$name.make" ] || block "Generated $name.make missing"; done
STAGE=$(mktemp -d "$D/preflight-g4.XXXXXXXX")
printf '%s  %s\n' "$G0_SHA" "$D/surface_rt_cross_preflight_g0_g3_20261017.sh" | sha256sum -c - || block 'G0-G3 script hash mismatch'
printf 'AS2K=%s\nMAME=%s\nG0_STAGE=%s\n' "$AS2K_SHA" "$MAME_SHA" "$STAGE_PREV" > "$STAGE/pins.txt"
pass 'PINNED snapshots, G0-G3 PASS status, generated makefiles and bx overlay validated'

STEP=G4_GENERATED_RECIPES
# The generated .make files are the source of truth for compiler flags.
# Use -n -B to print a single target's compile recipe, never build it.
# No source changes and no top-level `make` invocation.
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
unset PKG_CONFIG_PATH || :
# Prevent host compiler fallback even when generated makefiles have incomplete overrides.
export CROSS_BUILD=1 PTR64=0 PLATFORM=arm NOASM=1 FORCE_DRC_C_BACKEND=1
export OVERRIDE_CC="$WRAP/arm-cc" OVERRIDE_CXX="$WRAP/arm-cxx" OVERRIDE_LD="$WRAP/arm-cxx" OVERRIDE_AR="$TOOL/bin/arm-linux-ar"
export NO_OPENGL=1 USE_QTDEBUG=0 NO_USE_XINPUT=1 NO_USE_PORTAUDIO=1 NO_USE_PULSEAUDIO=1
export NO_USE_PIPEWIRE=1 NO_USE_MIDI=1 USE_TAPTUN=0 USE_PCAP=0 NOWERROR=1
export MAKEFLAGS='ARCHITECTURE='
# Record exact planned recipe without executing it; reject if it is not a single cross-compile.
python3 - "$WORK" "$STAGE" "$STAGE_PREV/overrides" "$WRAP/arm-cxx" "$MAME" <<'PY'
import os, pathlib, shlex, subprocess, sys
work, stage, overrides, wrapper, srcroot = map(pathlib.Path, sys.argv[1:])
# Map only known single objects; no link targets or generated sources.
candidates = [
    ('bx_file', 'bx.make', 'obj/Release/3rdparty/bx/src/file.o', '3rdparty/bx/src/file.cpp'),
    ('recording', 'emu.make', 'obj/Release/src/emu/recording.o', 'src/emu/recording.cpp'),
    ('sdlmain', 'osd_sdl.make', 'obj/Release/src/osd/sdl/sdlmain.o', 'src/osd/sdl/sdlmain.cpp'),
    ('emumem_aspace', 'emu.make', 'obj/Release/src/emu/emumem_aspace.o', 'src/emu/emumem_aspace.cpp'),
]
for label, mk, obj, source in candidates:
    if not (srcroot/source).is_file(): raise SystemExit(f'BLOCKED: missing source {source}')
    cmd=['make','--no-print-directory','-n','-B','-f',mk,'config=release','CXX='+str(wrapper),obj]
    p=subprocess.run(cmd,cwd=work,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=35)
    (stage/f'{label}.make-dry-run.txt').write_text(p.stdout)
    if p.returncode: raise SystemExit(f'BLOCKED: make -n for {label} rc={p.returncode}: {p.stdout[-1200:]}')
    good=[]
    for ln in p.stdout.splitlines():
        if ' -c ' not in f' {ln} ' or source not in ln: continue
        try: argv=shlex.split(ln.strip())
        except ValueError: continue
        if '-c' not in argv or '-o' not in argv: continue
        if argv[0].lstrip('@')!=str(wrapper): continue
        if any(a in (';','|','&&','||','>','<') for a in argv): continue
        if not any(source in a for a in argv): continue
        good.append(argv)
    if len(good)!=1: raise SystemExit(f'BLOCKED: {label} expected exactly 1 cross compiler recipe; got {len(good)}; inspect staged {label}.make-dry-run.txt')
    argv=good[0]
    for flag in ('-c','-o'):
        if flag not in argv: raise SystemExit(f'BLOCKED: {label} command missing {flag}')
    oi=argv.index('-o')+1
    if oi==len(argv): raise SystemExit(f'BLOCKED: {label} malformed -o')
    argv[oi]=str(stage/f'{label}.o')
    for opt in ('-MF','-MT','-MQ'):
        if opt in argv:
            i=argv.index(opt)+1
            if i==len(argv): raise SystemExit(f'BLOCKED: malformed {opt}')
            argv[i]=str(stage/f'{label}.d' if opt=='-MF' else stage/f'{label}.o')
    # No untracked writes inside source or generated make directories.
    argv.insert(1,'-D_LARGEFILE64_SOURCE=1')
    argv.insert(2,'-I'+str(overrides))
    # Explicitly keep compiler arguments and make cwd; no `shell=True`/eval.
    (stage/f'{label}.argv').write_text('\n'.join(argv)+'\n')
    print(f'[G4_RECIPE] {label}: validated target={obj}; actual generated flags recovered')
PY
pass 'Four compile recipes extracted from generated MAME makefiles; target is staging-only'

STEP=G4_SENTINEL_COMPILE
# Execute at most four compilers, one per file. Never run `make` in execution mode.
python3 - "$WORK" "$STAGE" <<'PY'
import os, pathlib, subprocess, sys
work=pathlib.Path(sys.argv[1]); stage=pathlib.Path(sys.argv[2])
for label in ('bx_file','recording','sdlmain','emumem_aspace'):
    argv=(stage/f'{label}.argv').read_text().splitlines()
    assert len(argv)>8 and argv[0].endswith('/arm-cxx')
    out=stage/f'{label}.o'
    assert '-o' in argv and argv[argv.index('-o')+1]==str(out)
    print(f'[G4_COMPILE] {label} using cross compiler; output={out}',flush=True)
    try:
        with (stage/f'{label}.compiler.log').open('w') as log:
            p=subprocess.run(argv,cwd=work,stdout=log,stderr=subprocess.STDOUT,timeout=240,env=os.environ.copy())
    except subprocess.TimeoutExpired:
        raise SystemExit(f'BLOCKED: sentinel {label} exceeded 240s; no full build permitted')
    if p.returncode: raise SystemExit(f'BLOCKED: sentinel {label} compile rc={p.returncode}; inspect compiler log')
    if not out.is_file() or out.stat().st_size<100: raise SystemExit(f'BLOCKED: sentinel {label} output missing/empty')
    hdr=subprocess.run(['readelf','-h',str(out)],capture_output=True,text=True)
    attrs=subprocess.run(['readelf','-A',str(out)],capture_output=True,text=True)
    if hdr.returncode or 'Machine:                           ARM' not in hdr.stdout:
        raise SystemExit(f'BLOCKED: sentinel {label} is not ARM ELF')
    if attrs.returncode or 'Tag_ABI_VFP_args: VFP registers' not in attrs.stdout:
        raise SystemExit(f'BLOCKED: sentinel {label} lacks ARM EABI hardfloat attributes')
    print(f'[G4_COMPILE] PASS {label} size={out.stat().st_size}',flush=True)
PY
pass 'Four representative ARMv7/musl object files compiled, no full MAME build'
STEP=G4_COMPLETE
pass 'G4 PASS: separate sentinel objects only. G5 full build NOT AUTHORIZED. No install, VONTAR and Surface untouched.'
