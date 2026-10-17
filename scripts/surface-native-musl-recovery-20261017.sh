#!/bin/sh
# Surface RT ONLY: resume pinned native AS2K Stable MAME build with reversible bx-musl compatibility.
# No T640, no install, no package upgrade, no clean, no ROM/NVRAM changes.
set -eu
umask 077
R=/home/user/Projects/alphasmart/as2k-surf-native
S="$R/status"
L="$R/logs"
AS2K="$R/sources/AS2K-Emulator"
MAME="$R/sources/mame-as3k"
OUT="$R/scripts/surface-native-build-musl-20261017.sh"
STATUS="$S/native-musl-20261017.status"
LOG="$L/native-musl-20261017.log"
STEP=INIT
mkdir -p "$S" "$L"
[ ! -e "$STATUS" ] || { echo 'BLOCKED: recovery job already attempted; no automatic retry'; exit 3; }
finish(){ rc=$?; trap - EXIT; if [ "$rc" -eq 0 ]; then printf 'STATUS=PASS\nSTEP=%s\nAS2K=%s\nMAME=%s\n' "$STEP" 36996b91053969661371dc067d49026fab367a47 1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b > "$STATUS"; else printf 'STATUS=FAIL\nRC=%s\nSTEP=%s\nAS2K=%s\nMAME=%s\n' "$rc" "$STEP" 36996b91053969661371dc067d49026fab367a47 1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b > "$STATUS"; fi; }
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
exec >> "$LOG" 2>&1
printf 'STATUS=RUNNING\nSTEP=INIT\n' > "$STATUS"
[ "$(uname -m)" = armv7l ] || { echo 'BLOCKED_NOT_SURFACE_ARMV7'; exit 2; }
[ "$(id -u)" -ne 0 ] || { echo 'BLOCKED_COMPILE_NOT_AS_ROOT'; exit 2; }
[ "$(cat "$S/environment.status")" = 'PASS STEP=READY' ] || { echo 'BLOCKED_ENVIRONMENT'; exit 2; }
[ "$(cat "$S/sources.status")" = 'PASS SOURCES_PINNED' ] || { echo 'BLOCKED_SOURCES'; exit 2; }
[ "$(cat "$S/build.status")" = 'FAIL EXIT=2 STEP=BUILD' ] || { echo 'BLOCKED_BUILD_STATE_CHANGED'; exit 2; }
[ "$(git -C "$AS2K" rev-parse HEAD)" = 36996b91053969661371dc067d49026fab367a47 ] || { echo 'BLOCKED_AS2K_PIN'; exit 2; }
[ "$(git -C "$MAME" rev-parse HEAD)" = 1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b ] || { echo 'BLOCKED_MAME_PIN'; exit 2; }
git -C "$AS2K" diff --quiet && git -C "$AS2K" diff --cached --quiet || { echo 'BLOCKED_AS2K_DIRTY'; exit 2; }
git -C "$MAME" diff --quiet && git -C "$MAME" diff --cached --quiet || { echo 'BLOCKED_MAME_DIRTY'; exit 2; }
[ -f "$R/scripts/surface-native-build.sh" ] || { echo 'BLOCKED_NATIVE_BUILDER_MISSING'; exit 2; }
[ ! -e "$OUT" ] || { echo 'BLOCKED_EXISTING_PATCHED_BUILD_COPY'; exit 2; }
[ "$(df -Pk "$R" | awk 'NR==2{print $4}')" -ge 10485760 ] || { echo 'BLOCKED_DISK_BELOW_10G'; exit 2; }
grep -Fq "$R/tmp/build-extra.swap " /proc/swaps || { echo 'BLOCKED_TEMP_SWAP_NOT_ACTIVE'; exit 2; }
if ps -eo args | grep -E '[m]ake -j1 SUBTARGET=as2k|[c]c1plus|[b]uild-stable-core.sh' >/dev/null; then
  echo 'BLOCKED_CONCURRENT_COMPILER'; exit 2
fi
STEP=PREPARE_SAFE_NATIVE_BUILDER
printf 'STATUS=RUNNING\nSTEP=PREPARE_SAFE_NATIVE_BUILDER\n' > "$STATUS"
# This generates a COPY of the already-proven native build script.
# The extra Python block patches the temporary donor files *inside* the existing
# build-stable-core's single EXIT restoration lifetime (after clean-source gates).
python3 -B - "$R/scripts/surface-native-build.sh" "$OUT" <<'PY_GENERATE'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
anchor='STEP=BUILD\necho "NATIVE_BUILD_RESUME'
if src.count(anchor)!=1: raise SystemExit('BLOCKED: native script build anchor changed')
addon=r"""# Compile-only musl adaptation lives in the generated, reversible builder.
python3 -B - "$OVERLAY/scripts/build-stable-core.sh" <<'PY_BX_BUILDER'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
changes=[
('cp "$MAME_LST" "$TMP_DIR/mame.lst"', '''cp "$MAME_LST" "$TMP_DIR/mame.lst"
BX_HDR="$MAME_TREE/3rdparty/bx/include/bx/platform.h"
BX_FILE="$MAME_TREE/3rdparty/bx/src/file.cpp"
[ -f "$BX_HDR" ] && [ -f "$BX_FILE" ] || { echo "BLOCKED bx source paths" >&2; exit 3; }
cp "$BX_HDR" "$TMP_DIR/bx.platform.h"
cp "$BX_FILE" "$TMP_DIR/bx.file.cpp"'''),
('    rm -rf "$TMP_DIR"', '''    cp "$TMP_DIR/bx.platform.h" "$BX_HDR"
    cp "$TMP_DIR/bx.file.cpp" "$BX_FILE"
    rm -rf "$TMP_DIR"'''),
("trap 'exit 143' TERM", r'''trap 'exit 143' TERM
# No change to the pinned AS2K engine/GTK; reversible third-party musl compatibility.
python3 -B - "$BX_HDR" "$BX_FILE" <<'PY_BX_COMPAT'
from pathlib import Path
import sys
h=Path(sys.argv[1]); f=Path(sys.argv[2])
s=h.read_text()
replacements=[
    ('#define BX_CRT_NEWLIB 0', '#define BX_CRT_NEWLIB 0\n#define BX_CRT_MUSL   0'),
    ('#\telif BX_PLATFORM_BSD\n#\t\tundef  BX_CRT_BSD\n#\t\tdefine BX_CRT_BSD 1', '#\telif BX_PLATFORM_BSD\n#\t\tundef  BX_CRT_BSD\n#\t\tdefine BX_CRT_BSD 1\n#\telif BX_PLATFORM_LINUX && !defined(__GLIBC__)\n#\t\tundef  BX_CRT_MUSL\n#\t\tdefine BX_CRT_MUSL 1'),
    ('\t&& !BX_CRT_NEWLIB', '\t&& !BX_CRT_NEWLIB \\\n\t&& !BX_CRT_MUSL'),
    ('#elif BX_CRT_NEWLIB', '#elif BX_CRT_MUSL\n#\tdefine BX_CRT_NAME "musl libc"\n#elif BX_CRT_NEWLIB'),
]
for before,after in replacements:
    if s.count(before)!=1: raise SystemExit('BLOCKED: bx/platform.h layout mismatch: '+before[:30])
    s=s.replace(before,after,1)
t=f.read_text()
before='#\telif 0                   \\'
# Preserve POSIX 64-bit offsets on musl; no glibc-specific functions.
after='#\telif BX_CRT_MUSL\n#\t\tdefine fseeko64 fseeko\n#\t\tdefine ftello64 ftello\n'+before
if t.count(before)!=1: raise SystemExit('BLOCKED: bx/file.cpp layout mismatch')
t=t.replace(before,after,1)
h.write_text(s); f.write_text(t)
PY_BX_COMPAT
# Fast target-platform proof *before* the expensive MAME make.
printf '#include <bx/platform.h>\n#if BX_CRT_NONE || !BX_CRT_MUSL\n#error BX musl/CRT misdetected\n#endif\n' | c++ -E -x c++ -I"$MAME_TREE/3rdparty/bx/include" - >/dev/null || exit 3
printf '#include <sys/types.h>\nstatic_assert(sizeof(off_t)==8, "musl off_t must be 64bit");\n' | c++ -std=c++17 -fsyntax-only -x c++ - || exit 3
c++ -std=c++17 -DBX_CONFIG_DEBUG=0 -I"$MAME_TREE/3rdparty/bx/include" -fsyntax-only "$MAME_TREE/3rdparty/bx/src/crtnone.cpp" "$BX_FILE" || exit 3
printf '%s\n' 'BX_MUSL_NATIVE_SYNTAX_PASS' ''')
]
for old,new in changes:
    if s.count(old)!=1: raise SystemExit('BLOCKED: pinned builder template mismatch: '+old[:44])
    s=s.replace(old,new,1)
p.write_text(s)
PY_BX_BUILDER
sh -n "$OVERLAY/scripts/build-stable-core.sh"
"""
src=src.replace('STEP=BUILD\necho', addon+'STEP=BUILD\necho',1)
Path(sys.argv[2]).write_text(src)
PY_GENERATE
sh -n "$OUT"
STEP=NATIVE_RESUME_BUILD
printf 'STATUS=RUNNING\nSTEP=NATIVE_RESUME_BUILD\n' > "$STATUS"
echo 'Starting incremental ARMv7 native compilation, J=1, already-built objects retained'
sh "$OUT"
STEP=VERIFY_NATIVE
[ "$(cat "$S/build.status")" = 'PASS STEP=READY' ] || { echo 'FAIL: build.status not PASS'; exit 5; }
BIN="$AS2K/out/as2k-bin"
[ -s "$BIN" ] || { echo 'FAIL: ELF missing'; exit 5; }
file "$BIN" | grep -Eq 'ELF 32-bit.*ARM' || { echo 'FAIL: target is not ARM32'; exit 5; }
readelf -h "$BIN" | grep -Eq 'Machine:.*ARM' || { echo 'FAIL: target architecture is not ARM'; exit 5; }
git -C "$AS2K" diff --quiet && git -C "$MAME" diff --quiet || { echo 'FAIL: source tree not restored'; exit 6; }
sha256sum "$BIN"
STEP=READY
echo 'NATIVE_SURFACE_MUSL_BUILD_PASS; NOT_INSTALLED'
