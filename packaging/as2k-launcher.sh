#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PREFIX=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)
AS2K_BIN="$PREFIX/libexec/as2k/as2k-bin"
AS2K_UI="$PREFIX/libexec/as2k/frontend/as2k_ui.py"

CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
RUNTIME_BASE=${XDG_RUNTIME_DIR:-"/tmp"}

AS2K_CONFIG="$CONFIG_HOME/as2k"
AS2K_DATA="$DATA_HOME/as2k"
AS2K_STATE="$STATE_HOME/as2k"
AS2K_RUNTIME="$RUNTIME_BASE/as2k-$(id -u)"

mkdir -p \
    "$AS2K_CONFIG/cfg" \
    "$AS2K_DATA/nvram" \
    "$AS2K_DATA/output" \
    "$AS2K_STATE/states" \
    "$AS2K_RUNTIME"
chmod 700 "$AS2K_RUNTIME"

FIRMWARE=${AS2K_FIRMWARE:-"$AS2K_CONFIG/firmware.bin"}
DICTROM=${AS2K_DICTROM:-"$AS2K_CONFIG/dictrom.bin"}

[ -x "$AS2K_BIN" ] || { echo "AS2K core not found: $AS2K_BIN" >&2; exit 127; }
[ -f "$AS2K_UI" ] || { echo "AS2K GTK frontend not found: $AS2K_UI" >&2; exit 127; }
[ -f "$FIRMWARE" ] || {
    echo "AS2K firmware not configured." >&2
    echo "Place/symlink it at: $FIRMWARE" >&2
    echo "or set AS2K_FIRMWARE=/path/to/firmware.bin" >&2
    exit 2
}
[ -f "$DICTROM" ] || {
    echo "AS2K DictROM not configured." >&2
    echo "Place/symlink it at: $DICTROM" >&2
    echo "or set AS2K_DICTROM=/path/to/dictrom.bin" >&2
    exit 2
}

CONTROL="$AS2K_RUNTIME/control.queue"
EVENTS="$AS2K_RUNTIME/events.queue"
FRAME="$AS2K_RUNTIME/lcd.bin"
: > "$CONTROL"
: > "$EVENTS"
rm -f "$FRAME"

CORE_LOG="$AS2K_STATE/core.log"
CORE_PID=""

cleanup()
{
    if [ -n "$CORE_PID" ] && kill -0 "$CORE_PID" 2>/dev/null; then
        kill "$CORE_PID" 2>/dev/null || true
        wait "$CORE_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT HUP INT TERM

export AS2K_UI_CONTROL_FILE="$CONTROL"
export AS2K_UI_EVENT_FILE="$EVENTS"
export AS2K_UI_FRAME_FILE="$FRAME"

"$AS2K_BIN" asma2k \
    -rom1 "$FIRMWARE" \
    -rom2 "$DICTROM" \
    -rompath "$(dirname -- "$FIRMWARE")" \
    -cfg_directory "$AS2K_CONFIG/cfg" \
    -nvram_directory "$AS2K_DATA/nvram" \
    -snapshot_directory "$AS2K_DATA/output" \
    -state_directory "$AS2K_STATE/states" \
    -video none -sound none \
    "$@" >"$CORE_LOG" 2>&1 &
CORE_PID=$!

sleep 1
if ! kill -0 "$CORE_PID" 2>/dev/null; then
    echo "AS2K core did not start. See: $CORE_LOG" >&2
    wait "$CORE_PID" || true
    exit 1
fi

python3 "$AS2K_UI"
