#!/bin/sh
# Directed AS2K core/UI regression: PC ON/OFF must wake firmware without KEY.
# This does not install the stable emulator or touch the user's NVRAM.
set -eu

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 CORE_BIN ROM1 DICTROM SEED_NVRAM_DIR PRIVATE_WORK_DIR" >&2
    exit 2
fi
CORE=$1 ROM=$2 DICT=$3 SEED=$4 WORK=$5
[ -x "$CORE" ] && [ -f "$ROM" ] && [ -f "$DICT" ] && [ -d "$SEED" ] || {
    echo "BLOCKED: missing explicit executable/private inputs"; exit 2;
}
[ ! -e "$WORK" ] || { echo "BLOCKED: output exists; never overwrite evidence"; exit 3; }
umask 077
mkdir -p "$WORK"/output "$WORK"/cfg "$WORK"/state "$WORK"/runtime
cp -a "$SEED" "$WORK/nvram"
: >"$WORK/control.queue"
: >"$WORK/events.queue"

cat >"$WORK/pc-wakeup.lua" <<'LUA'
local machine=manager.machine
local screen=assert(machine.screens[":screen"])
local control=assert(os.getenv("AS2K_UI_CONTROL_FILE"))
local frame=0
local buffers={}
local function marker(tag)
    local f=assert(io.open("wakeup.events","a"))
    f:write("AS2K_WAKE_",tag,"\n")
    f:close()
end
local function cmd(c)
    local f=assert(io.open(control,"a"));f:write(c,"\n");f:close()
end
local function snap(which)
    local bytes,w,h=screen:pixels()
    assert(bytes and w==240 and h==36)
    buffers[which]=bytes
    local err=screen:snapshot(which..".png")
    assert(not err)
    marker("SNAP_"..which)
end
local function delta(a,b)
    local n=0
    local x,y=buffers[a],buffers[b]
    for i=1, #x do
        if x:byte(i) ~= y:byte(i) then n=n+1 end
    end
    return n
end
emu.register_frame_done(function()
    frame=frame+1
    -- Allow 12 emulated seconds for normal firmware boot; no virtual keys.
    if frame==600 then snap("editor_before");cmd("PC ON");marker("PC_ON_SENT") end
    if frame==740 then snap("host_connected") end
    if frame==800 then cmd("PC ON");marker("PC_ON_REPEAT") end
    if frame==870 then cmd("PC OFF");marker("PC_OFF_SENT") end
    if frame==1010 then snap("editor_after") end
    if frame==1050 then cmd("PC OFF");marker("PC_OFF_REPEAT") end
    if frame==1100 then
        local a=delta("editor_before","host_connected")
        local b=delta("host_connected","editor_after")
        marker("DIFF_EDITOR_TO_HOST_"..a)
        marker("DIFF_HOST_TO_EDITOR_"..b)
        marker("NO_KEYBOARD_INJECTIONS")
        marker("COMPLETE")
        machine:exit()
    end
end,'as2k_pc_wakeup_test')
LUA

# Keep the exact private seed, renderer and wired-PC bridge from the closed
# AS2K UI Send test; only PC state changes are exercised in this regression.
ROMPATH=$(dirname -- "$ROM")
(
 cd "$WORK"
 XDG_RUNTIME_DIR="$WORK/runtime" \
 AS2K_UI_CONTROL_FILE="$WORK/control.queue" \
 AS2K_UI_EVENT_FILE="$WORK/events.queue" \
 AS2K_UI_FRAME_FILE="$WORK/lcd.bin" \
 "$CORE" asma2k -rom1 "$ROM" -rom2 "$DICT" -rompath "$ROMPATH" \
   -nvram_directory "$WORK/nvram" \
   -snapshot_directory "$WORK/output" \
   -cfg_directory "$WORK/cfg" \
   -state_directory "$WORK/state" \
   -video none -sound none -nothrottle -log -seconds_to_run 28 \
   -autoboot_script "$WORK/pc-wakeup.lua" \
   >"$WORK/stdout.log" 2>"$WORK/stderr.log"
)
grep -q '^AS2K_WAKE_COMPLETE$' "$WORK/wakeup.events" || {
    echo "FAIL: Lua test did not finish"; exit 4;
}
grep -q '^AS2K_WAKE_NO_KEYBOARD_INJECTIONS$' "$WORK/wakeup.events" || {
    echo "FAIL: keyboard was used"; exit 4;
}
[ -f "$WORK/output/editor_before.png" ] &&
[ -f "$WORK/output/host_connected.png" ] &&
[ -f "$WORK/output/editor_after.png" ] || {
    echo "FAIL: LCD evidence not captured"; exit 4;
}
[ -f "$WORK/error.log" ] || { echo "FAIL: MAME diagnostic event log missing"; exit 4; }
# Two changes only: PC ON then OFF. Repeated same-state commands MUST NOT IRQ.
count=$(grep -c 'AS2K_PC_HOST_EDGE_WAKE_IRQ source=ui attached=' "$WORK/error.log" || :)
[ "$count" -eq 2 ] || { echo "FAIL: expected 2 host-edge IRQ, got $count"; exit 4; }
grep -q 'AS2K_PC_HOST_EDGE_WAKE_IRQ source=ui attached=1' "$WORK/error.log" &&
grep -q 'AS2K_PC_HOST_EDGE_WAKE_IRQ source=ui attached=0' "$WORK/error.log" || {
    echo "FAIL: missing one edge direction"; exit 4;
}
echo "AS2K PC HOST-EDGE IRQ: PASS (two real transitions, no keyboard)"
echo "AS2K LCD FIRMWARE MODE: VISUAL_REVIEW_REQUIRED"
echo "Private runtime evidence: $WORK"
