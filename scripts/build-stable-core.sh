#!/bin/sh
set -eu

usage()
{
    echo "Usage: $0 MAME_TREE [JOBS]" >&2
    exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage

MAME_TREE=$1
JOBS=${2:-1}

case "$JOBS" in
    ''|*[!0-9]*) echo "JOBS must be a positive integer" >&2; exit 2 ;;
    0) echo "JOBS must be greater than zero" >&2; exit 2 ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
MAME_TREE=$(CDPATH= cd -- "$MAME_TREE" && pwd)

DRIVER_SRC="$REPO_DIR/src/mame/skeleton/alphasma.cpp"
DRIVER_DST="$MAME_TREE/src/mame/skeleton/alphasma.cpp"
HC11_CPP="$MAME_TREE/src/devices/cpu/mc68hc11/mc68hc11.cpp"
HC11_H="$MAME_TREE/src/devices/cpu/mc68hc11/mc68hc11.h"
HC11_PAI_PATCH="$REPO_DIR/patches/mc68hc11-pai.patch"
MAME_LST="$MAME_TREE/src/mame/mame.lst"
OUT_DIR="$REPO_DIR/out"
OUT_BIN="$OUT_DIR/as2k-bin"

[ -f "$DRIVER_SRC" ] || { echo "Missing reduced AS2K driver: $DRIVER_SRC" >&2; exit 2; }
[ -f "$DRIVER_DST" ] || { echo "Not a compatible MAME tree: $DRIVER_DST missing" >&2; exit 2; }
[ -f "$HC11_CPP" ] || { echo "Not a compatible MAME tree: $HC11_CPP missing" >&2; exit 2; }
[ -f "$HC11_H" ] || { echo "Not a compatible MAME tree: $HC11_H missing" >&2; exit 2; }
[ -f "$HC11_PAI_PATCH" ] || { echo "Missing recovered HC11 PAI patch: $HC11_PAI_PATCH" >&2; exit 2; }
[ -f "$MAME_LST" ] || { echo "Not a compatible MAME tree: $MAME_LST missing" >&2; exit 2; }
[ -f "$MAME_TREE/makefile" ] || { echo "Not a compatible MAME tree: makefile missing" >&2; exit 2; }

TMP_DIR=$(mktemp -d)
cp "$DRIVER_DST" "$TMP_DIR/alphasma.cpp"
cp "$HC11_CPP" "$TMP_DIR/mc68hc11.cpp"
cp "$HC11_H" "$TMP_DIR/mc68hc11.h"
cp "$MAME_LST" "$TMP_DIR/mame.lst"

restore()
{
    cp "$TMP_DIR/alphasma.cpp" "$DRIVER_DST"
    cp "$TMP_DIR/mc68hc11.cpp" "$HC11_CPP"
    cp "$TMP_DIR/mc68hc11.h" "$HC11_H"
    cp "$TMP_DIR/mame.lst" "$MAME_LST"
    rm -rf "$TMP_DIR"
}
trap restore EXIT HUP INT TERM

cp "$DRIVER_SRC" "$DRIVER_DST"

# Recover only the already-validated HC11 PA7/PAI pulse-accumulator support
# needed by the AS2000 IrDA peer.  The donor CPU sources are restored on exit.
cd "$MAME_TREE"
patch --batch --forward -p1 < "$HC11_PAI_PATCH"

# MAME's global mame.lst still associates skeleton/alphasma.cpp with AlphaSmart
# Pro. The reduced driver intentionally omits that machine. Remove only that
# one entry while generating this target, then restore the donor list on exit.
awk '
    /^@source:/ { in_as2k = ($0 == "@source:skeleton/alphasma.cpp") }
    in_as2k && $0 == "asmapro" { next }
    { print }
' "$TMP_DIR/mame.lst" > "$MAME_LST"

# USE_QTDEBUG=0 changes the generated source list, but a stale libqtdbg_sdl.a
# built previously with Qt enabled can still be reused by make. Remove only
# these derived debugger artifacts so the non-Qt configuration is rebuilt.
if [ -d "$MAME_TREE/build" ]; then
    find "$MAME_TREE/build" -type f -name 'libqtdbg_sdl.a' -delete
    find "$MAME_TREE/build" -type d -name 'qtdbg_sdl' -prune -exec rm -rf {} +
fi

cd "$MAME_TREE"
make -j"$JOBS" \
    SUBTARGET=as2k \
    SOURCES=src/mame/skeleton/alphasma.cpp \
    REGENIE=1 \
    USE_QTDEBUG=0

./as2k -validate

mkdir -p "$OUT_DIR"
cp ./as2k "$OUT_BIN"
chmod 0755 "$OUT_BIN"

printf '%s\n' "AS2K reduced core build: PASS"
printf '%s\n' "Validated binary: $OUT_BIN"
