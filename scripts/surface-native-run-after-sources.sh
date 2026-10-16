#!/bin/sh
# Run one native AS2K Stable build on Surface RT, only after exact sources PASS.
# No installation, no source modifications beyond build-stable-core's reversible
# donor patching. Designed for one unattended Commander launch/status read.
set -eu
umask 077
R="$HOME/Projects/alphasmart/as2k-surf-native"
S="$R/status"
L="$R/logs"
mkdir -p "$S" "$L"
[ "$(uname -m)" = "armv7l" ] || { echo "BLOCKED: not ARMv7 Surface"; exit 2; }
[ -f "$R/scripts/surface-native-build.sh" ] || { echo "BLOCKED: native build script missing"; exit 2; }
[ -f "$S/environment.status" ] && grep -Fxq "PASS STEP=READY" "$S/environment.status" ||
    { echo "BLOCKED: native environment not ready"; exit 2; }

LOCK="$S/native-build-run.lock"
mkdir "$LOCK" || { echo "BLOCKED: build runner already active or stale lock"; exit 3; }
STEP=WAIT_SOURCES
finish() {
    rc=$?
    rmdir "$LOCK" 2>/dev/null || :
    if [ "$rc" -eq 0 ]; then
        echo "PASS NATIVE_BUILD_COMPLETE" > "$S/native-build-run.status"
    elif [ "$rc" -eq 4 ]; then
        printf 'BLOCKED STEP=%s RC=%s\n' "$STEP" "$rc" > "$S/native-build-run.status"
    else
        printf 'FAIL STEP=%s RC=%s\n' "$STEP" "$rc" > "$S/native-build-run.status"
    fi
}
trap finish EXIT
echo "RUNNING STEP=WAIT_SOURCES" > "$S/native-build-run.status"
# Source fetch may still be running from the preceding increment. Poll only
# *inside this local unattended shell*, not by repeated Commander calls.
remaining=360
while :; do
    result=$(cat "$S/sources.status" 2>/dev/null || :)
    case "$result" in
        "PASS SOURCES_PINNED") break ;;
        FAIL*|BLOCKED*)
            echo "BLOCKED: source stage failed: $result"
            exit 4 ;;
        "RUNNING SOURCE_STAGE"|LAUNCHED|"")
            [ "$remaining" -gt 0 ] ||
                { echo "BLOCKED: source stage did not finish in allotted wait"; exit 4; }
            remaining=$((remaining - 1))
            sleep 20 ;;
        *)
            echo "BLOCKED: unrecognized source stage state: $result"
            exit 4 ;;
    esac
done

STEP=PIN_VERIFY
[ "$(git -C "$R/sources/AS2K-Emulator" rev-parse HEAD)" = "36996b91053969661371dc067d49026fab367a47" ] ||
    { echo "BLOCKED: incorrect AS2K revision"; exit 4; }
[ "$(git -C "$R/sources/mame-as3k" rev-parse HEAD)" = "1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b" ] ||
    { echo "BLOCKED: incorrect donor MAME revision"; exit 4; }
[ -s "$R/sources/AS2K-Emulator/scripts/build-stable-core.sh" ] ||
    { echo "BLOCKED: missing pinned builder"; exit 4; }
[ -s "$R/sources/mame-as3k/makefile" ] ||
    { echo "BLOCKED: missing MAME makefile"; exit 4; }
[ "$(df -Pk "$R" | awk 'NR==2{print $4}')" -ge 10485760 ] ||
    { echo "BLOCKED: less than 10 GiB free"; exit 4; }

STEP=NATIVE_COMPILE
printf 'RUNNING STEP=NATIVE_COMPILE\n' > "$S/native-build-run.status"
echo "NATIVE_BUILD_BEGIN $(date -u) J=1"
if sh "$R/scripts/surface-native-build.sh" > "$L/native-build.log" 2>&1; then
    [ "$(cat "$S/build.status")" = "PASS STEP=READY" ] ||
        { echo "FAIL: build script returned 0 without PASS status"; exit 5; }
    echo "NATIVE_BUILD_COMPLETE $(date -u)"
    echo "BINARY=$R/sources/AS2K-Emulator/out/as2k-bin"
    echo "NO_INSTALLATION"
else
    rc=$?
    echo "FAIL: native build terminated rc=$rc; inspect $L/native-build.log"
    exit "$rc"
fi
