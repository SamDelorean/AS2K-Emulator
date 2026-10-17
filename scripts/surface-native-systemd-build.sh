#!/bin/sh
# Surface RT native MAME build entrypoint for a systemd transient service.
# Must run as unprivileged user, outside desktop-commander.service cgroup.
set -eu
umask 077
R="$HOME/Projects/alphasmart/as2k-surf-native"
S="$R/status"
L="$R/logs"
mkdir -p "$S" "$L"
STEP=START
finish() {
  rc=$?
  if [ "$rc" -eq 0 ]; then
    printf 'PASS STEP=READY\n' > "$S/systemd-build.status"
  else
    printf 'FAIL RC=%s STEP=%s\n' "$rc" "$STEP" > "$S/systemd-build.status"
  fi
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
[ "$(id -u)" -ne 0 ] || { echo "BLOCKED: must compile as user"; exit 2; }
[ "$(cat "$S/sources.status")" = "PASS SOURCES_PINNED" ] || { echo "BLOCKED: source stage"; exit 2; }
[ "$(cat "$S/environment.status")" = "PASS STEP=READY" ] || { echo "BLOCKED: environment"; exit 2; }
[ -f "$R/scripts/surface-native-run-after-sources.sh" ] || { echo "BLOCKED: runner missing"; exit 2; }
STEP=NATIVE_BUILD
printf 'RUNNING STEP=NATIVE_BUILD\n' > "$S/systemd-build.status"
printf 'START=%s PID=%s CGROUP=%s\n' "$(date -Iseconds)" "$$" "$(cat /proc/self/cgroup)" > "$L/systemd-build-meta.log"
sh "$R/scripts/surface-native-run-after-sources.sh" > "$L/native-build-runner.log" 2>&1
[ "$(cat "$S/native-build-run.status")" = "PASS NATIVE_BUILD_COMPLETE" ] || { echo "FAIL: runner missing PASS"; exit 5; }
[ "$(cat "$S/build.status")" = "PASS STEP=READY" ] || { echo "FAIL: builder missing PASS"; exit 5; }
[ -x "$R/sources/AS2K-Emulator/out/as2k-bin" ] || { echo "FAIL: binary missing"; exit 5; }
STEP=READY
echo "AS2K_ARMV7_BUILD_PASS $(date -Iseconds)"
echo "NO_INSTALLATION"
