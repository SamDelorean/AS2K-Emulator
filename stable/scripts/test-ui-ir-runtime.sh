#!/bin/sh
set -eu

usage()
{
    echo "Usage: $0 CORE_BIN ROM1 DICTROM SEND_NVRAM_DIR PRINT_NVRAM_DIR" >&2
    exit 2
}

[ "$#" -eq 5 ] || usage
CORE_BIN=$1
ROM1=$2
DICTROM=$3
SEND_NVRAM=$4
PRINT_NVRAM=$5

[ -x "$CORE_BIN" ] || { echo "CORE_BIN is not executable" >&2; exit 2; }
[ -f "$ROM1" ] || { echo "ROM1 not found" >&2; exit 2; }
[ -f "$DICTROM" ] || { echo "DICTROM not found" >&2; exit 2; }
[ -d "$SEND_NVRAM" ] || { echo "SEND_NVRAM_DIR not found" >&2; exit 2; }
[ -d "$PRINT_NVRAM" ] || { echo "PRINT_NVRAM_DIR not found" >&2; exit 2; }

CORE_BIN=$(CDPATH= cd -- "$(dirname -- "$CORE_BIN")" && pwd)/$(basename -- "$CORE_BIN")
ROM1=$(CDPATH= cd -- "$(dirname -- "$ROM1")" && pwd)/$(basename -- "$ROM1")
DICTROM=$(CDPATH= cd -- "$(dirname -- "$DICTROM")" && pwd)/$(basename -- "$DICTROM")
SEND_NVRAM=$(CDPATH= cd -- "$SEND_NVRAM" && pwd)
PRINT_NVRAM=$(CDPATH= cd -- "$PRINT_NVRAM" && pwd)

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM
ROMPATH=$(dirname -- "$ROM1")

run_case()
{
    kind=$1
    dir="$WORK/$kind"
    mkdir -p "$dir"/output "$dir"/cfg "$dir"/state "$dir"/runtime
    if [ "$kind" = SEND ]; then
        cp -a "$SEND_NVRAM" "$dir/nvram"
    else
        cp -a "$PRINT_NVRAM" "$dir/nvram"
    fi
    chmod 700 "$dir/runtime"
    : > "$dir/control.queue"
    : > "$dir/events.queue"

    cat > "$dir/run.lua" <<'LUA'
local cpu=assert(manager.machine.devices[':maincpu'])
local nat=manager.machine.natkeyboard
local control=assert(os.getenv('AS2K_UI_CONTROL_FILE'))
local events=assert(os.getenv('AS2K_UI_EVENT_FILE'))
local mode=assert(os.getenv('AS2K_IR_TEST_MODE'))
local stage,frames,idle,delay=0,0,0,0

local function cmd(s)
  local f=assert(io.open(control,'a'))
  f:write(s,'\n')
  f:close()
end

local function complete()
  local f=io.open(events,'r')
  if not f then return false end
  local s=f:read('*a')
  f:close()
  return s:find('IR_DONE',1,true) ~= nil
end

cmd('IR ON')
emu.register_frame_done(function()
  frames=frames+1
  if frames>4200 then print('IR_TEST TIME_LIMIT '..mode); manager.machine:exit(); return end
  if complete() then print('IR_TEST COMPLETE '..mode); manager.machine:exit(); return end
  if delay>0 then delay=delay-1; return end

  if stage==0 then
    if cpu.state.PC.value==0x87d7 and nat.empty then idle=idle+1 else idle=0 end
    if idle<60 then return end
    nat:post_coded('{F1}')
    stage=1; delay=120; return
  end

  if stage==1 then
    if mode=='SEND' then
      nat:post_coded('IR TEST 123')
      stage=2; delay=420
    else
      nat:post('IR PRINT MULTIFRAME 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ')
      stage=2; delay=420
    end
    return
  end

  if stage==2 and mode=='PRINT' then
    nat:post_coded('{ENTER}')
    stage=3; delay=120; return
  end

  if stage==3 and mode=='PRINT' then
    nat:post('SECOND LINE 9876543210 ZYXWVUTSRQPONMLKJIHGFEDCBA')
    stage=4; delay=420; return
  end

  if (mode=='SEND' and stage==2) or (mode=='PRINT' and stage==4) then
    cmd(mode=='SEND' and 'KEY SEND' or 'KEY PRINT')
    stage=9; delay=120
    return
  end
end,'as2k_ir_runtime')
LUA

    (
      cd "$dir"
      XDG_RUNTIME_DIR="$dir/runtime" \
      AS2K_UI_CONTROL_FILE="$dir/control.queue" \
      AS2K_UI_EVENT_FILE="$dir/events.queue" \
      AS2K_UI_FRAME_FILE="$dir/lcd.bin" \
      AS2K_IR_TEST_MODE="$kind" \
      "$CORE_BIN" asma2k \
        -rom1 "$ROM1" -rom2 "$DICTROM" -rompath "$ROMPATH" \
        -nvram_directory "$dir/nvram" \
        -snapshot_directory "$dir/output" \
        -cfg_directory "$dir/cfg" \
        -state_directory "$dir/state" \
        -video none -sound none -nothrottle -seconds_to_run 40 \
        -autoboot_script "$dir/run.lua" > "$dir/stdout.log" 2> "$dir/stderr.log"
    )

    grep -q "IR_BYTES	$kind	" "$dir/events.queue" ||
      { echo "FAIL: $kind produced no IR_BYTES event" >&2; cat "$dir/events.queue" >&2; exit 1; }
    grep -q '^IR_DONE$' "$dir/events.queue" ||
      { echo "FAIL: $kind did not reach IR_DONE" >&2; cat "$dir/events.queue" >&2; exit 1; }

    if find "$dir/output" -type f \( -name '*.txt' -o -name '*.pdf' -o -name '*.pcl' -o -name '*.prn' \) | grep -q .; then
      echo "FAIL: $kind created a persisted TXT/PDF/PCL/PRN artifact" >&2
      find "$dir/output" -type f -print >&2
      exit 1
    fi

    bytes=$(awk -F '\t' -v m="$kind" '$1=="IR_BYTES" && $2==m { n+=split($3,a," ") } END { print n+0 }' "$dir/events.queue")
    [ "$bytes" -gt 0 ] || { echo "FAIL: $kind byte count is zero" >&2; exit 1; }
    printf 'AS2K IR %s runtime: PASS bytes=%s\n' "$kind" "$bytes"
}

run_case SEND
run_case PRINT
printf '%s\n' "AS2K UI IR runtime: PASS"
