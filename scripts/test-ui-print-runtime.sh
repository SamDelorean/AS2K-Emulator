#!/bin/sh
set -eu

usage()
{
    echo "Usage: $0 CORE_BIN ROM1 DICTROM SEED_NVRAM_DIR EXPECTED_TEXT" >&2
    exit 2
}

[ "$#" -eq 5 ] || usage
CORE_BIN=$1
ROM1=$2
DICTROM=$3
SEED_NVRAM=$4
EXPECTED_TEXT=$5

[ -x "$CORE_BIN" ] || { echo "CORE_BIN is not executable" >&2; exit 2; }
[ -f "$ROM1" ] || { echo "ROM1 not found" >&2; exit 2; }
[ -f "$DICTROM" ] || { echo "DICTROM not found" >&2; exit 2; }
[ -d "$SEED_NVRAM" ] || { echo "SEED_NVRAM_DIR not found" >&2; exit 2; }

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM

mkdir -p "$WORK"/output "$WORK"/cfg "$WORK"/state "$WORK"/runtime
cp -a "$SEED_NVRAM" "$WORK/nvram"
chmod 700 "$WORK/runtime"
: > "$WORK/control.queue"
: > "$WORK/events.queue"

cat > "$WORK/print-ui.lua" <<'LUA'
local cpu=assert(manager.machine.devices[':maincpu'])
local nat=manager.machine.natkeyboard
local control=assert(os.getenv('AS2K_UI_CONTROL_FILE'))
local text=assert(os.getenv('AS2K_PRINT_TEST_TEXT'))
local stage,frames,idle=0,0,0
local function cmd(s)
  local f=assert(io.open(control,'a'))
  f:write(s,'\n')
  f:close()
end
cmd('PRINTER ON')
emu.register_frame_done(function()
  frames=frames+1
  if stage<3 then
    if cpu.state['PC'].value==0x87d7 and nat.empty then idle=idle+1 else idle=0 end
    if idle<65 then return end
    idle=0
    if stage==0 then nat:post_coded('{F1}')
    elseif stage==1 then nat:post(text)
    elseif stage==2 then cmd('KEY PRINT') end
    stage=stage+1
    return
  end
  if frames>2200 then manager.machine:exit() end
end,'as2k_ui_print_runtime')
LUA

ROMPATH=$(dirname -- "$ROM1")
XDG_RUNTIME_DIR="$WORK/runtime" \
AS2K_UI_CONTROL_FILE="$WORK/control.queue" \
AS2K_UI_EVENT_FILE="$WORK/events.queue" \
AS2K_UI_FRAME_FILE="$WORK/lcd.bin" \
AS2K_PRINT_TEST_TEXT="$EXPECTED_TEXT" \
"$CORE_BIN" asma2k \
  -rom1 "$ROM1" -rom2 "$DICTROM" -rompath "$ROMPATH" \
  -nvram_directory "$WORK/nvram" \
  -snapshot_directory "$WORK/output" \
  -cfg_directory "$WORK/cfg" \
  -state_directory "$WORK/state" \
  -video none -sound none -nothrottle -seconds_to_run 25 \
  -autoboot_script "$WORK/print-ui.lua" > "$WORK/stdout.log" 2> "$WORK/stderr.log"

PCL_PATH=$(awk -F '\t' '$1=="PRINT_READY"{print $2}' "$WORK/events.queue" | tail -1)
[ -n "$PCL_PATH" ] || { echo "FAIL: PRINT_READY event missing" >&2; exit 1; }
[ -f "$PCL_PATH" ] || { echo "FAIL: completed PCL capture missing" >&2; exit 1; }

python3 - "$PCL_PATH" "$EXPECTED_TEXT" <<'PY'
from pathlib import Path
import sys
raw=Path(sys.argv[1]).read_bytes()
text=sys.argv[2].encode('ascii')
assert raw.startswith(b'\x1bE\x1b&k3G'), 'unexpected PCL prologue'
assert raw.endswith(b'\x1b&l0H\x1bE'), 'unexpected PCL terminator'
assert text in raw, 'expected printable text absent from physical printer capture'
print(f'AS2K wired PCL capture: PASS bytes={len(raw)}')
PY

PDF_PATH="$WORK/as2k-print-test.pdf"
python3 "$REPO_DIR/frontend/as2k_pcl_to_pdf.py" "$PCL_PATH" "$PDF_PATH"
python3 - "$PDF_PATH" <<'PY'
from pathlib import Path
import sys
data=Path(sys.argv[1]).read_bytes()
assert data.startswith(b'%PDF-') and len(data)>1000, 'invalid CUPS PDF result'
print(f'AS2K wired CUPS PDF: PASS bytes={len(data)}')
PY

printf '%s\n' "AS2K UI Print runtime: PASS"
