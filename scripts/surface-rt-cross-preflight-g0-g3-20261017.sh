#!/usr/bin/env bash
# AS2K Stable VONTAR -> Surface RT: bounded preflight only; NO MAME full build.
# This script is staged for a separately authorized T640 dispatch. Do not run
# it as part of preparation on ChatGPT; it is designed for the existing T640.
set -Eeuo pipefail
umask 077

D=/home/spc/Projects/alphasmart/as2k-surface-cross
TOOL="$D/armv7-eabihf--musl--stable-2025.08-1"
SYSROOT="$D/alpine-armv7-sysroot"
AS2K="$D/work/AS2K-Emulator-vontar-b3"
MAME="$D/work/mame-as3k"
AS2K_SHA=36996b91053969661371dc067d49026fab367a47
MAME_SHA=1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b
V6_SHA=0adc04f13d9bed7a0c1dd3070dda065723045baabc63afd8f669d107d1430805
EVIDENCE=googledrive:AS2K_TEMP/surface-rt/results/vontar-36996b9/preflight-g0-g3
STATUS="$D/preflight-g0-g3-20261017.status"
LOG="$D/preflight-g0-g3-20261017.log"
STEP=INIT
STAGE=''
pass(){ printf '[%s] PASS: %s\n' "$STEP" "$*"; }
block(){ printf '[%s] BLOCKED: %s\n' "$STEP" "$*" >&2; exit 2; }
finish(){
  rc=$?
  trap - EXIT
  mkdir -p "$D"
  if [ "$rc" -eq 0 ]; then
    printf 'STATUS=PASS\nGATES=G0_G1_G2_G3\nG4=NOT_EXECUTED\nG5=NOT_AUTHORIZED\nAS2K=%s\nMAME=%s\nSTAGE=%s\n' "$AS2K_SHA" "$MAME_SHA" "$STAGE" > "$STATUS"
  else
    printf 'STATUS=BLOCKED\nSTEP=%s\nRC=%s\nG4=NOT_EXECUTED\nG5=NOT_AUTHORIZED\nAS2K=%s\nMAME=%s\nSTAGE=%s\n' "$STEP" "$rc" "$AS2K_SHA" "$MAME_SHA" "$STAGE" > "$STATUS"
  fi
  { rclone mkdir "$EVIDENCE" && rclone copyto "$STATUS" "$EVIDENCE/$(basename "$STATUS")" && rclone copyto "$LOG" "$EVIDENCE/$(basename "$LOG")"; } >/dev/null 2>&1 || printf 'EVIDENCE_UPLOAD_FAIL: inspect local status/log, no build occurred\n' >&2
  exit "$rc"
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$D"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

STEP=G0_PINNED_SOURCES
for c in git bash python3 pkg-config sha256sum file readelf grep sed awk make rclone timeout; do
  command -v "$c" >/dev/null 2>&1 || block "Required existing command missing: $c"
done
[ -d "$AS2K/.git" ] && [ -d "$MAME/.git" ] || block 'Isolated frozen checkouts absent; no checkout/fetch/reset attempted'
[ "$(git -C "$AS2K" rev-parse HEAD)" = "$AS2K_SHA" ] || block 'AS2K is not approved VONTAR revision'
[ "$(git -C "$MAME" rev-parse HEAD)" = "$MAME_SHA" ] || block 'MAME donor revision differs'
git -C "$AS2K" diff --quiet && git -C "$AS2K" diff --cached --quiet || block 'AS2K tracked changes present'
git -C "$MAME" diff --quiet && git -C "$MAME" diff --cached --quiet || block 'MAME tracked changes present'
[ -s "$D/as2k_surface_rt_cross_build_t640_v6.sh" ] || block 'V6 reference script absent'
printf '%s  %s\n' "$V6_SHA" "$D/as2k_surface_rt_cross_build_t640_v6.sh" | sha256sum -c - || block 'V6 reference script hash changed'
[ -f "$AS2K/scripts/build-stable-core.sh" ] && [ -f "$MAME/3rdparty/bx/src/file.cpp" ] || block 'Pinned source layout unexpected'
STAGE=$(mktemp -d "$D/preflight-g0-g3.XXXXXXXX")
printf 'AS2K_SHA=%s\nMAME_SHA=%s\nV6_SHA=%s\n' "$AS2K_SHA" "$MAME_SHA" "$V6_SHA" > "$STAGE/pins.txt"
pass 'Approved work clones and script hash verified; no tracked sources modified'

STEP=G1_TOOLCHAIN_ABI
CC="$TOOL/bin/arm-linux-gcc"; CXX="$TOOL/bin/arm-linux-g++"; READELF="$TOOL/bin/arm-linux-readelf"
for p in "$CC" "$CXX" "$TOOL/bin/arm-linux-ar"; do [ -x "$p" ] || block "Toolchain executable absent: $p"; done
TARGET=$($CXX -dumpmachine)
[ "$TARGET" = arm-buildroot-linux-musleabihf ] || block "Compiler target unexpectedly $TARGET"
{
  printf 'TARGET=%s\n' "$TARGET"
  "$CXX" -v
  printf 'COMPILER_SYSROOT='; "$CXX" -print-sysroot
  printf 'CRT1='; "$CXX" -print-file-name=crt1.o
  printf 'LIBSTDCPP='; "$CXX" -print-file-name=libstdc++.so
  printf 'LIBGCC='; "$CXX" -print-libgcc-file-name
  printf 'PKG_CONFIG_SYSROOT_DIR=%s\n' "$SYSROOT"
} > "$STAGE/toolchain-report.txt" 2>&1
CRT1=$($CXX -print-file-name=crt1.o)
STDCPP=$($CXX -print-file-name=libstdc++.so)
[ -f "$CRT1" ] && [ -f "$STDCPP" ] || block 'Toolchain missing CRT startup or libstdc++ file'
[ -e "$SYSROOT/usr/lib/libSDL2.so" ] && [ -e "$SYSROOT/usr/lib/libX11.so" ] || block 'Existing Alpine armv7 dependencies missing'
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
unset PKG_CONFIG_PATH || :
pkg-config --exists sdl2 SDL2_ttf fontconfig x11 xinerama || block 'Target SDL/X11/Fontconfig pkg-config missing'
pkg-config --cflags --libs sdl2 SDL2_ttf fontconfig x11 xinerama > "$STAGE/pkg-flags.txt"
# Keep internal MAME headers ahead of the external Alpine sysroot.
printf '#include <iostream>\nint main(){ std::cout << "armv7"; return 0; }\n' > "$STAGE/abi.cpp"
"$CXX" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard \
  -idirafter "$SYSROOT/usr/include" -L"$SYSROOT/usr/lib" \
  -Wl,-rpath-link,"$SYSROOT/usr/lib" -Wl,-rpath-link,"$SYSROOT/lib" \
  "$STAGE/abi.cpp" -o "$STAGE/abi-armv7" || block 'C++20/libstdc++ cross link is incompatible'
file "$STAGE/abi-armv7" | grep -Eq 'ELF 32-bit.*ARM' || block 'Linked ABI probe is not ELF ARM32'
readelf -h "$STAGE/abi-armv7" > "$STAGE/elf-header.txt"
readelf -A "$STAGE/abi-armv7" > "$STAGE/elf-attributes.txt"
readelf -l "$STAGE/abi-armv7" > "$STAGE/elf-program-headers.txt"
readelf -d "$STAGE/abi-armv7" > "$STAGE/elf-needed.txt"
grep -q 'ld-musl-armhf.so.1' "$STAGE/elf-program-headers.txt" || block 'ARM probe lacks musl armhf interpreter'
grep -q 'Tag_ABI_VFP_args: VFP registers' "$STAGE/elf-attributes.txt" || block 'ARM probe lacks hard-float attribute'
if readelf --version-info "$STAGE/abi-armv7" 2>/dev/null | grep -Eq 'GLIBC_[0-9]'; then block 'GLIBC version requirement leaked into ARM musl probe'; fi
cat > "$STAGE/targetlibs.cpp" <<'CPP'
#include <SDL.h>
#include <SDL_ttf.h>
#include <fontconfig/fontconfig.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xinerama.h>
int main(){ SDL_version ver{}; SDL_GetVersion(&ver); auto x = &XOpenDisplay;
  auto ttf = &TTF_Init; auto fc = &FcInit; auto xin = &XineramaIsActive;
  return (x && ttf && fc && xin) ? 0 : 1; }
CPP
# Exercise external shared-library resolution, not just a trivial C++ binary.
"$CXX" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard \
  -idirafter "$SYSROOT/usr/include" -L"$SYSROOT/usr/lib" \
  -Wl,-rpath-link,"$SYSROOT/usr/lib" -Wl,-rpath-link,"$SYSROOT/lib" \
  $(pkg-config --cflags sdl2 SDL2_ttf fontconfig x11 xinerama) \
  "$STAGE/targetlibs.cpp" -o "$STAGE/targetlibs-armv7" \
  $(pkg-config --libs sdl2 SDL2_ttf fontconfig x11 xinerama) \
  || block 'Actual ARMv7 SDL2/X11/Fontconfig link fails'
readelf -d "$STAGE/targetlibs-armv7" > "$STAGE/external-needed.txt"
if readelf --version-info "$STAGE/targetlibs-armv7" 2>/dev/null | grep -Eq 'GLIBC_[0-9]'; then block 'GLIBC requirement in external library test'; fi
pass 'ARMv7 hard-float, musl interpreter, startup, C++ runtime and sysroot smoke link checked'

STEP=G2_LIBC_BX_PNG
# Compile and LINK; do not execute ARM binaries on T640. Verify actual libc declarations.
cat > "$STAGE/largefile.cpp" <<'CPP'
#define _LARGEFILE64_SOURCE 1
#include <stdio.h>
#include <sys/types.h>
#include <type_traits>
static_assert(sizeof(off_t)==8, "off_t must be 64-bit");
int main(){ auto seekfn = &::fseeko64; auto tellfn = &::ftello64;
  return (seekfn && tellfn) ? 0 : 1; }
CPP
"$CXX" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard \
  -idirafter "$SYSROOT/usr/include" -L"$SYSROOT/usr/lib" \
  "$STAGE/largefile.cpp" -o "$STAGE/largefile-armv7" || block 'Real ARM musl headers/libc do not provide fseeko64/ftello64 with feature macro'
file "$STAGE/largefile-armv7" | grep -Eq 'ELF 32-bit.*ARM' || block 'Largefile test did not produce ARM32 ELF'
# MAME's own util/png.h must win over Alpine system libpng png.h.
printf '#include "png.h"\n#ifndef MAME_LIB_UTIL_PNG_H\n#error MAME png.h was shadowed\n#endif\nint main(){ return 0; }\n' > "$STAGE/mamepng.cpp"
"$CXX" -std=c++20 -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard \
  -I"$MAME/src/lib/util" -idirafter "$SYSROOT/usr/include" \
  -c "$STAGE/mamepng.cpp" -o "$STAGE/mamepng-armv7.o" || block 'MAME png.h was shadowed'
# Verify bx CRT musl patch semantics on a COPY ONLY, no tracked source edits.
mkdir -p "$STAGE/overrides/bx"
cp "$MAME/3rdparty/bx/include/bx/platform.h" "$STAGE/overrides/bx/platform.h"
python3 - "$STAGE/overrides/bx/platform.h" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
a='#define BX_CRT_NEWLIB 0'; b=a+'\n#define BX_CRT_MUSL   0'
c='#\telif BX_PLATFORM_BSD\n#\t\tundef  BX_CRT_BSD\n#\t\tdefine BX_CRT_BSD 1'
d=c+'\n#\telif defined(__linux__) && !defined(__GLIBC__)\n#\t\tundef  BX_CRT_MUSL\n#\t\tdefine BX_CRT_MUSL 1'
e='\t&& !BX_CRT_NEWLIB'; f=e+' \\\n\t&& !BX_CRT_MUSL'
g='#elif BX_CRT_NEWLIB'; h='#elif BX_CRT_MUSL\n#\tdefine BX_CRT_NAME "musl libc"\n'+g
for old,new in [(a,b),(c,d),(e,f),(g,h)]:
    if s.count(old)!=1: raise SystemExit('BLOCKED: bx version/pattern changed')
    s=s.replace(old,new,1)
p.write_text(s)
PY
printf '#include <bx/platform.h>\n#if BX_CRT_NONE || !BX_CRT_MUSL\n#error bx musl CRT invalid\n#endif\n' | \
  "$CXX" -std=c++20 -E -x c++ -I"$STAGE/overrides" -I"$MAME/3rdparty/bx/include" - >/dev/null \
  || block 'bx musl CRT classifier failed'
pass 'musl largefile declarations and link, bx classifier and MAME PNG precedence checked'

STEP=G3_MAME_CONFIG_AND_SAFE_BUILDER
# The official MAME cross-build interface is CROSS_BUILD=1 + OVERRIDE_*;
# assert it exists in our pinned donor, not a fabricated make convention.
grep -Fq 'CROSS_BUILD := 1' "$MAME/makefile" || block 'Cross build support not found in donor makefile'
grep -Fq 'OVERRIDE_CXX' "$MAME/makefile" || block 'OVERRIDE_CXX support not found in donor makefile'
grep -Fq 'REGENIE=1' "$AS2K/scripts/build-stable-core.sh" || block 'Builder lacks regeneration contract'
# Only prepare corrected generated builder in STAGE; never execute it here.
python3 - "$AS2K/scripts/build-stable-core.sh" "$STAGE/safe-builder.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
a='REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)'
b='REPO_DIR=${AS2K_WORK_REPO:?Must supply pinned AS2K isolated work clone}'
if s.count(a)!=1: raise SystemExit('BLOCKED: original builder path changed')
s=s.replace(a,b,1)
a='TMP_DIR=$(mktemp -d)'
b='TMP_DIR=$(mktemp -d "${AS2K_CROSS_SNAPSHOT_ROOT:?Set existing cross-build snapshot root}/snapshot.XXXXXXXX")'
if s.count(a)!=1: raise SystemExit('BLOCKED: original builder snapshot pattern changed')
s=s.replace(a,b,1)
a='trap restore EXIT HUP INT TERM'
b="trap restore EXIT\ntrap 'exit 129' HUP\ntrap 'exit 130' INT\ntrap 'exit 143' TERM"
if s.count(a)!=1: raise SystemExit('BLOCKED: original builder trap pattern changed')
s=s.replace(a,b,1)
a='./as2k -validate\n'
if s.count(a)!=1: raise SystemExit('BLOCKED: native-only validation contract changed')
s=s.replace(a,'',1)
Path(sys.argv[2]).write_text(s)
PY
sh -n "$STAGE/safe-builder.sh" || block 'Generated safe builder syntax invalid'
! grep -Fq 'trap restore EXIT HUP INT TERM' "$STAGE/safe-builder.sh" || block 'Double restore trap survived'
! grep -Fq './as2k -validate' "$STAGE/safe-builder.sh" || block 'Cross builder still executes target binary on T640'
[ -f "$MAME/build/as2k-surface-armv7-cross/projects/sdl/mameas2k/gmake-linux/Makefile" ] \
  || block 'Original generated MAME target Makefile absent; no automatic regeneration in preflight'
[ -f "$MAME/build/as2k-surface-armv7-cross/projects/sdl/mameas2k/gmake-linux/emu.make" ] \
  || block 'Generated emu.make absent; no full build to create it'
[ -f "$MAME/build/as2k-surface-armv7-cross/projects/sdl/mameas2k/gmake-linux/bx.make" ] \
  || block 'Generated bx.make absent; no full build to create it'
# Inspect without changing generated projects; stale regeneration parameters
# must be handled separately before compiling any significant target.
printf 'CROSS_BUILD=1\nTARGETOS=linux\nPTR64=0\nPLATFORM=arm\nARCHITECTURE=(empty)\nREGENIE=1\nUSE_QTDEBUG=0\nLIBC_EXTRA=-D_LARGEFILE64_SOURCE (subject to G2)\nINCLUDE_PRIORITY=-idirafter\n' > "$STAGE/required-compiler-contract.txt"
pass 'Official cross-build contract and safe-builder overlay audited; generated project files available'

STEP=PREFLIGHT_COMPLETE
pass 'G0-G3 PASS only. G4 sentinel object compiles NOT run; full MAME build NOT authorized; Surface untouched'
