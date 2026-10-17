#!/bin/sh
# Execute once via Commander. Proves kernel OOM and launches MAME build
# as independent systemd service with temporary 4 GiB ext4 swap.
# Never installs AS2K or touches boot, ROM, NVRAM or kernel configuration.
set -eu
umask 077
R="$HOME/Projects/alphasmart/as2k-surf-native"
S="$R/status"
L="$R/logs"
SWAP="$R/tmp/build-extra.swap"
UNIT="as2k-surface-native-20261016"
mkdir -p "$S" "$L" "$R/tmp"
[ "$(uname -m)" = armv7l ] || { echo "BLOCKED: wrong architecture"; exit 2; }
[ "$(cat "$S/environment.status")" = "PASS STEP=READY" ] || { echo "BLOCKED: environment"; exit 2; }
[ "$(cat "$S/sources.status")" = "PASS SOURCES_PINNED" ] || { echo "BLOCKED: sources"; exit 2; }
[ "$(git -C "$R/sources/AS2K-Emulator" rev-parse HEAD)" = 36996b91053969661371dc067d49026fab367a47 ] || exit 2
[ "$(git -C "$R/sources/mame-as3k" rev-parse HEAD)" = 1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b ] || exit 2
[ -z "$(git -C "$R/sources/AS2K-Emulator" status --porcelain --untracked-files=no)" ] || exit 2
[ -z "$(git -C "$R/sources/mame-as3k" status --porcelain --untracked-files=no)" ] || exit 2
sh -n "$R/scripts/surface-native-systemd-build.sh"
sh -n "$R/scripts/surface-native-run-after-sources.sh"
sh -n "$R/scripts/surface-native-build.sh"
sudo -n true || { echo "BLOCKED: no sudo"; exit 2; }
if systemctl is-active --quiet "$UNIT.service"; then echo "BLOCKED: systemd build already active"; exit 3; fi
if ps -eo args | grep -E '[m]ake -j1 SUBTARGET=as2k|[c]c1plus|[b]uild-stable-core.sh' >/dev/null; then
  echo "BLOCKED: other compiler active"; exit 3
fi
# Verify the exact prior failure was OOM, not a C++ compiler diagnostic.
journalctl -k --since '2026-10-16 10:45' --until '2026-10-16 10:55' --no-pager |
  grep -F 'Out of memory: Killed process' | grep -F '(cc1plus)' >/dev/null ||
  { echo "BLOCKED: no verified cc1plus OOM evidence"; exit 3; }
[ "$(df -Pk "$R" | awk 'NR==2{print $4}')" -ge 10485760 ] ||
  { echo "BLOCKED: insufficient disk"; exit 3; }
# Prevent blindly overwriting existing swap files.
if [ -e "$SWAP" ]; then
  grep -Fq "$SWAP " /proc/swaps || { echo "BLOCKED: existing swap path inactive"; exit 3; }
else
  sudo -n fallocate -l 4G "$SWAP"
  sudo -n chmod 0600 "$SWAP"
  sudo -n mkswap "$SWAP" > "$L/build-extra-swap-setup.log" 2>&1
  sudo -n swapon -p -2 "$SWAP"
fi
grep -Fq "$SWAP " /proc/swaps || { echo "BLOCKED: swap not active"; exit 4; }
# Old jobs have been confirmed absent; archive only active lock names.
for lock in "$S/build.lock" "$S/native-build-run.lock"; do
  if [ -d "$lock" ]; then
    mv "$lock" "$lock.oom-20261016"
  fi
done
printf 'SWAP_ACTIVE path=%s\n' "$SWAP" > "$S/oom-recovery.status"
sudo -n systemd-run --system --no-block --collect --unit="$UNIT" \
  --description='AS2K Stable native ARMv7 compile isolated from Commander' \
  -p User="$(id -un)" -p WorkingDirectory="$R" -p OOMPolicy=continue \
  /bin/sh "$R/scripts/surface-native-systemd-build.sh"
echo "SERVICE_LAUNCHED $UNIT.service"
systemctl show "$UNIT.service" -p ActiveState -p SubState -p MainPID -p ControlGroup -p Result --no-pager
echo "SWAP_ACTIVE:"
grep -F "$SWAP " /proc/swaps
echo "STATUS:"
cat "$S/systemd-build.status" 2>/dev/null || :
echo "NO_INSTALLATION"
