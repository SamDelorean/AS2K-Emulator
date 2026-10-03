#!/bin/sh
set -eu

usage()
{
    echo "Usage: $0 CORE_BIN ROM1 DICTROM SEED_NVRAM_DIR EXPECTED_SINGLE" >&2
    exit 2
}

[ "$#" -eq 5 ] || usage

CORE_BIN=$1
ROM1=$2
DICTROM=$3
SEED_NVRAM=$4
EXPECTED_SINGLE=$5

[ -x "$CORE_BIN" ] || { echo "CORE_BIN is not executable" >&2; exit 2; }
[ -f "$ROM1" ] || { echo "ROM1 not found" >&2; exit 2; }
[ -f "$DICTROM" ] || { echo "DICTROM not found" >&2; exit 2; }
[ -d "$SEED_NVRAM" ] || { echo "SEED_NVRAM_DIR not found" >&2; exit 2; }

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM

mkdir -p "$WORK"/output "$WORK"/cfg "$WORK"/state "$WORK"/runtime
cp -a "$SEED_NVRAM" "$WORK/nvram"
chmod 700 "$WORK/runtime"
: > "$WORK/control.queue"
: > "$WORK/events.queue"

cat > "$WORK/send-ui.lua" <<'LUA'
local cpu=assert(manager.machine.devices[':maincpu'])
local control=assert(os.getenv('AS2K_UI_CONTROL_FILE'))
local ready=false
local n=0
local requested=false
local function cmd(s)
  local f=assert(io.open(control,'a'))
  f:write(s,'\n')
  f:close()
end
emu.register_frame_done(function()
  if not requested then cmd('PC ON'); requested=true end
  if not ready and cpu.state['PC'].value==0x80e5 then ready=true end
  if not ready then return end
  n=n+1
  if n==20 or n==300 then cmd('KEY SEND') end
  if n==600 then cmd('PC OFF') end
  if n==660 then manager.machine:exit() end
end,'as2k_ui_send_runtime')
LUA

ROMPATH=$(dirname -- "$ROM1")
XDG_RUNTIME_DIR="$WORK/runtime" \
AS2K_UI_CONTROL_FILE="$WORK/control.queue" \
AS2K_UI_EVENT_FILE="$WORK/events.queue" \
AS2K_UI_FRAME_FILE="$WORK/lcd.bin" \
"$CORE_BIN" asma2k \
  -rom1 "$ROM1" -rom2 "$DICTROM" -rompath "$ROMPATH" \
  -nvram_directory "$WORK/nvram" \
  -snapshot_directory "$WORK/output" \
  -cfg_directory "$WORK/cfg" \
  -state_directory "$WORK/state" \
  -video none -sound none -nothrottle -seconds_to_run 20 \
  -autoboot_script "$WORK/send-ui.lua" > "$WORK/stdout.log" 2> "$WORK/stderr.log"

SEND_PATH=$(awk -F '\t' '$1=="SEND_READY"{print $2}' "$WORK/events.queue" | tail -1)
[ -n "$SEND_PATH" ] || { echo "FAIL: SEND_READY event missing" >&2; exit 1; }
[ -f "$SEND_PATH" ] || { echo "FAIL: completed Send capture missing" >&2; exit 1; }

ACTUAL=$(cat "$SEND_PATH")
EXPECTED=${EXPECTED_SINGLE}${EXPECTED_SINGLE}
[ "$ACTUAL" = "$EXPECTED" ] || {
    echo "FAIL: Send capture mismatch" >&2
    printf 'expected: %s\nactual:   %s\n' "$EXPECTED" "$ACTUAL" >&2
    exit 1
}

printf '%s\n' "AS2K UI Send runtime: PASS"
printf 'capture: %s\n' "$ACTUAL"
