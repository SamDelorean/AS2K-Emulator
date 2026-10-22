#!/bin/sh
# Compile AS2K Stable directly on Surface RT (ARMv7/musl), NEVER on T640.
# Separate from prep and installation; intentionally default to one make job.
set -eu
umask 077
[ "$(uname -m)" = armv7l ] || { echo "BLOCKED: ARMv7 hardware required"; exit 2; }
WORK="$HOME/Projects/alphasmart/as2k-surf-native"
AS2K="$WORK/sources/AS2K-Emulator"
MAME="$WORK/sources/mame-as3k"
[ -d "$AS2K/.git" ] && [ -d "$MAME/.git" ] ||
    { echo "BLOCKED: source stage absent; run surface-native-fetch-sources.sh"; exit 2; }
[ "$(git -C "$AS2K" rev-parse HEAD)" = 36996b91053969661371dc067d49026fab367a47 ] ||
    { echo "BLOCKED: AS2K source not VONTAR Stable pin"; exit 2; }
[ "$(git -C "$MAME" rev-parse HEAD)" = 1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b ] ||
    { echo "BLOCKED: MAME donor revision mismatch"; exit 2; }
git -C "$AS2K" diff --quiet && git -C "$AS2K" diff --cached --quiet ||
    { echo "BLOCKED: AS2K sources modified; do not overwrite"; exit 2; }
git -C "$MAME" diff --quiet && git -C "$MAME" diff --cached --quiet ||
    { echo "BLOCKED: MAME donor modified; do not overwrite"; exit 2; }
mkdir -p "$WORK/status" "$WORK/logs"
STATUS="$WORK/status/build.status"
LOCK="$WORK/status/build.lock"
mkdir "$LOCK" || { echo "BLOCKED: another build or stale lock; manual review"; exit 3; }
STEP=START
finish() {
    rc=$?
    rmdir "$LOCK" 2>/dev/null || :
    if [ "$rc" -eq 0 ]; then printf 'PASS STEP=%s\n' "$STEP" > "$STATUS"
    else printf 'FAIL EXIT=%s STEP=%s\n' "$rc" "$STEP" > "$STATUS"; fi
}
trap finish EXIT
STEP=PREFLIGHT
FREE_KB=$(df -Pk "$WORK" | awk 'NR==2 {print $4}')
[ "$FREE_KB" -ge 10485760 ] ||
    { echo "BLOCKED: less than 10 GiB free"; exit 3; }
[ -f "$WORK/status/environment.status" ] &&
grep -Fq 'PASS STEP=READY' "$WORK/status/environment.status" ||
    { echo "BLOCKED: native environment not prepared"; exit 3; }
sh "$AS2K/scripts/validate-stable-static.sh"
# Pin ARMv7 native settings: makefile otherwise misdetects armv7l as _x86.
export MAKEFLAGS="ARCHITECTURE="
export PLATFORM=arm
export NOASM=1
export FORCE_DRC_C_BACKEND=1
export NO_OPENGL=1
export NO_USE_XINPUT=1
export NO_USE_PORTAUDIO=1
export NO_USE_PULSEAUDIO=1
export NO_USE_PIPEWIRE=1
export NO_USE_MIDI=1
export USE_QTDEBUG=0
export NOWERROR=1
export OPTIMIZE=1
export REGENIE=1
# Build only through a minimal work overlay. Leave the pinned Git checkout
# untouched, and store restore snapshots on persistent ext4 (not volatile /tmp).
# The original MAME builder's trap executes restore on BOTH TERM and EXIT,
# which causes a second restore after the scratch directory is removed.
STEP=SAFE_OVERLAY
OVERLAY="$WORK/build-overlay"
mkdir -p "$OVERLAY/scripts" "$OVERLAY/src/mame/skeleton" "$OVERLAY/out" "$WORK/tmp" "$AS2K/out"
cp "$AS2K/src/mame/skeleton/alphasma.cpp" "$OVERLAY/src/mame/skeleton/alphasma.cpp"
cp "$AS2K/scripts/patch-mc68hc11-pai.py" "$OVERLAY/scripts/"
cp "$AS2K/scripts/patch-mc68hc11-bootstrap.py" "$OVERLAY/scripts/"
export AS2K_SAFE_TMPDIR="$WORK/tmp"
python3 -B - "$AS2K/scripts/build-stable-core.sh" "$OVERLAY/scripts/build-stable-core.sh" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding="utf-8")
replacements = (
    (
        "TMP_DIR=$(mktemp -d)",
        'TMP_DIR=$(mktemp -d "$AS2K_SAFE_TMPDIR/restore.XXXXXXXX")',
    ),
    (
        "trap restore EXIT HUP INT TERM",
        "trap restore EXIT\ntrap 'exit 129' HUP\ntrap 'exit 130' INT\ntrap 'exit 143' TERM",
    ),
)
for old, new in replacements:
    if src.count(old) != 1:
        raise SystemExit("BLOCKED: unrecognized pinned MAME builder layout")
    src = src.replace(old, new, 1)
Path(sys.argv[2]).write_text(src, encoding="utf-8")
PY
sh -n "$OVERLAY/scripts/build-stable-core.sh"

STEP=BUILD
echo "NATIVE_BUILD_RESUME ARMv7 J=1 $(date -u) objects retained"
sh "$OVERLAY/scripts/build-stable-core.sh" "$MAME" 1
STEP=VERIFY
BIN="$OVERLAY/out/as2k-bin"
[ -x "$BIN" ] || { echo "FAIL: compiled executable missing"; exit 4; }
file "$BIN" | grep -Eq 'ELF 32-bit.*ARM' ||
    { echo "FAIL: not ARMv7 ELF"; exit 4; }
readelf -h "$BIN" | grep -Eq 'Machine:.*ARM' ||
    { echo "FAIL: non-ARM target"; exit 4; }
# build-stable-core.sh already executes ./as2k -validate on native Surface.

# Only publish a verified binary to the exact pinned tree's out/ folder;
# do not touch any system installation.
FINAL="$AS2K/out/as2k-bin"
TMPBIN=$(mktemp "$AS2K/out/.as2k-bin-stage.XXXXXXXX")
cp "$BIN" "$TMPBIN"
chmod 0755 "$TMPBIN"
mv -f "$TMPBIN" "$FINAL"

STEP=READY
echo "NATIVE_BUILD_PASS $FINAL"
echo "NOT_INSTALLED; run surface-native-install.sh only after approval"
