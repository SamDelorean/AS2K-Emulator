#!/bin/sh
set -eu

usage()
{
    echo "Usage: $0 CORE_BIN ROM1 DICTROM SEED_NVRAM_DIR" >&2
    exit 2
}

[ "$#" -eq 4 ] || usage
CORE_BIN=$1
ROM1=$2
DICTROM=$3
SEED_NVRAM=$4

[ -x "$CORE_BIN" ] || { echo "CORE_BIN is not executable" >&2; exit 2; }
[ -f "$ROM1" ] || { echo "ROM1 not found" >&2; exit 2; }
[ -f "$DICTROM" ] || { echo "DICTROM not found" >&2; exit 2; }
[ -d "$SEED_NVRAM" ] || { echo "SEED_NVRAM_DIR not found" >&2; exit 2; }

CORE_BIN=$(CDPATH= cd -- "$(dirname -- "$CORE_BIN")" && pwd)/$(basename -- "$CORE_BIN")
ROM1=$(CDPATH= cd -- "$(dirname -- "$ROM1")" && pwd)/$(basename -- "$ROM1")
DICTROM=$(CDPATH= cd -- "$(dirname -- "$DICTROM")" && pwd)/$(basename -- "$DICTROM")
SEED_NVRAM=$(CDPATH= cd -- "$SEED_NVRAM" && pwd)

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM

cat > "$WORK/kbd.lua" <<'LUA'
local cpu=assert(manager.machine.devices[':maincpu'])
local nat=manager.machine.natkeyboard
local mode=assert(os.getenv('AS2K_KBD_MODE'))
local control=assert(os.getenv('AS2K_UI_CONTROL_FILE'))
local frames,idle,stage,delay=0,0,0,0

local function cmd(s)
  local f=assert(io.open(control,'a'))
  f:write(s,'\n')
  f:close()
end

emu.register_frame_done(function()
  frames=frames+1
  if frames>1800 then
    print('KBD_TIMEOUT '..mode)
    manager.machine:exit()
    return
  end
  if delay>0 then delay=delay-1; return end

  if stage==0 then
    if cpu.state.PC.value==0x87d7 and nat.empty then idle=idle+1 else idle=0 end
    if idle<60 then return end
    if mode=='NAT' then
      nat:post('a')
      stage=2
      delay=180
    else
      cmd('KEYDOWN A')
      stage=1
      delay=5
    end
    return
  end

  if stage==1 then
    cmd('KEYUP A')
    stage=2
    delay=180
    return
  end

  if stage==2 then
    print('KBD_DONE '..mode)
    manager.machine:exit()
  end
end,'kbd_bridge')
LUA

for MODE in NAT UI; do
    DIR="$WORK/$MODE"
    mkdir -p "$DIR/nvram" "$DIR/cfg" "$DIR/state" "$DIR/output" "$DIR/runtime"
    cp -a "$SEED_NVRAM"/. "$DIR/nvram"/
    : > "$DIR/control.queue"
    : > "$DIR/events.queue"

    (
      cd "$DIR"
      XDG_RUNTIME_DIR="$DIR/runtime" \
      AS2K_UI_CONTROL_FILE="$DIR/control.queue" \
      AS2K_UI_EVENT_FILE="$DIR/events.queue" \
      AS2K_UI_FRAME_FILE="$DIR/lcd.bin" \
      AS2K_KBD_MODE="$MODE" \
      "$CORE_BIN" asma2k \
        -rom1 "$ROM1" -rom2 "$DICTROM" -rompath "$(dirname -- "$ROM1")" \
        -nvram_directory "$DIR/nvram" \
        -snapshot_directory "$DIR/output" \
        -cfg_directory "$DIR/cfg" \
        -state_directory "$DIR/state" \
        -video none -sound none -nothrottle \
        -autoboot_script "$WORK/kbd.lua" -seconds_to_run 25 \
        > "$DIR/stdout.log" 2> "$DIR/stderr.log"
    )

    grep -q "KBD_DONE $MODE" "$DIR/stdout.log" ||
      { echo "FAIL: $MODE did not complete" >&2; cat "$DIR/stdout.log" >&2; exit 1; }
    [ -s "$DIR/lcd.bin" ] || { echo "FAIL: $MODE LCD frame missing" >&2; exit 1; }
done

cmp "$WORK/NAT/lcd.bin" "$WORK/UI/lcd.bin" >/dev/null ||
  { echo "FAIL: UI keyboard matrix result diverges from native keyboard result" >&2; exit 1; }

echo "AS2K ordinary keyboard bridge runtime: PASS"
