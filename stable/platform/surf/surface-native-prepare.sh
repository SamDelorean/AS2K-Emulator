#!/bin/sh
# Surface RT (postmarketOS 26.06): prepare native ARMv7 toolchain only.
# No source fetch, firmware change, kernel update, MAME build or app install.
set -eu
umask 077
WORK="$HOME/Projects/alphasmart/as2k-surf-native"
mkdir -p "$WORK/status" "$WORK/logs" "$WORK/sources" "$WORK/out" "$WORK/backup"
STATUS="$WORK/status/environment.status"
STEP=BASELINE
finish() {
    rc=$?
    if [ "$rc" -eq 0 ]; then printf 'PASS STEP=%s\n' "$STEP" > "$STATUS"
    else printf 'FAIL EXIT=%s STEP=%s\n' "$rc" "$STEP" > "$STATUS"; fi
}
trap finish EXIT
[ "$(uname -m)" = armv7l ] || { echo "BLOCKED: expected armv7l"; exit 2; }
[ -f /etc/os-release ] || { echo "BLOCKED: missing os-release"; exit 2; }
grep -Eq '^ID="?postmarketos"?$' /etc/os-release || { echo "BLOCKED: not postmarketOS"; exit 2; }
grep -Fq 'VERSION_ID="v26.06"' /etc/os-release || { echo "BLOCKED: OS release changed"; exit 2; }
command -v apk >/dev/null || { echo "BLOCKED: apk absent"; exit 2; }
command -v sudo >/dev/null || { echo "BLOCKED: sudo absent"; exit 2; }
sudo -n true || { echo "BLOCKED: passwordless sudo unavailable"; exit 2; }

STEP=PACKAGES
# Native toolchain and GTK/SDL dependencies only. Never apk upgrade; never
# change postmarketOS kernel, bootloader or DTB. Install ONLY absent packages.
REQUIRED="build-base git python3 py3-gobject3 gtk+3.0 gtk+3.0-dev pkgconf
sdl2-dev sdl2_ttf-dev fontconfig-dev libx11-dev libxinerama-dev
libxi-dev libxrandr-dev libxrender-dev libxext-dev linux-headers
ca-certificates file binutils"
MISSING=""
for package in $REQUIRED; do
    if ! apk info -e "$package" >/dev/null 2>&1; then
        MISSING="$MISSING $package"
    fi
done
if [ -n "$MISSING" ]; then
    echo "Installing missing ARMv7 packages:$MISSING"
    # Intentional word splitting of validated literal package names.
    sudo -n apk add --no-progress $MISSING
else
    echo "PACKAGE_REUSE_PASS: all build dependencies already installed"
fi
STEP=VERIFY
for c in gcc g++ make git python3 pkg-config file readelf; do
    command -v "$c" >/dev/null || { echo "BLOCKED: absent tool $c"; exit 3; }
done
gcc -dumpmachine | grep -Eq '^arm' || { echo "BLOCKED: gcc not ARM"; exit 3; }
pkg-config --exists sdl2 SDL2_ttf fontconfig x11 xinerama ||
    { echo "BLOCKED: SDL2/GTK X11 development metadata"; exit 3; }
python3 -B -c 'import gi; gi.require_version("Gtk", "3.0"); from gi.repository import Gtk' ||
    { echo "BLOCKED: GTK3 Python binding"; exit 3; }
# Internal eMMC storage, not /boot or removable USB (none was mounted in baseline).
FREE_KB=$(df -Pk "$WORK" | awk 'NR==2 {print $4}')
[ "$FREE_KB" -ge 10485760 ] ||
    { echo "BLOCKED: less than 10 GiB free; do not begin native MAME build"; exit 3; }
STEP=READY
echo "ENVIRONMENT_PASS ARMv7-native postmarketOS-v26.06"
echo "WORK=$WORK"
echo "FREE_KB=$FREE_KB"
echo "JOBS_RECOMMENDED=1"
echo "NO_SOURCES_FETCHED NO_COMPILATION NO_INSTALLATION"
