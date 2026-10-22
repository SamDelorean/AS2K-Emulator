#!/bin/sh
# Controlled installation of verified native ARMv7 AS2K on Surface RT.
# This script is NEVER invoked by prepare, fetch-sources, or build.
set -eu
umask 077
[ "$(uname -m)" = armv7l ] || { echo "BLOCKED: ARMv7 required"; exit 2; }
WORK="$HOME/Projects/alphasmart/as2k-surf-native"
AS2K="$WORK/sources/AS2K-Emulator"
BIN="$AS2K/out/as2k-bin"
[ -x "$BIN" ] || { echo "BLOCKED: no compiled AS2K"; exit 2; }
[ -f "$WORK/status/build.status" ] &&
grep -Fq 'PASS STEP=READY' "$WORK/status/build.status" ||
    { echo "BLOCKED: build is not PASS"; exit 2; }
[ "$(git -C "$AS2K" rev-parse HEAD)" = 36996b91053969661371dc067d49026fab367a47 ] ||
    { echo "BLOCKED: unexpected AS2K source"; exit 2; }
"$BIN" -validate || { echo "BLOCKED: native executable failed validation"; exit 3; }
STAGE=$(mktemp -d "$WORK/.install-stage-XXXXXXXX")
BACKUP="$WORK/backup/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$STAGE/usr/local" "$BACKUP"
# Use the canonical release frontend, not the older pinned AS2K checkout:
# the original 2026-10-15 Surf source predates the Vontar session manager.
# This also avoids invoking the Vontar-only install-stable.sh with a staging
# PREFIX, which is intentionally rejected by that installer.
RELEASE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
for f in "$RELEASE_ROOT/frontend/as2k_ui.py" \
         "$RELEASE_ROOT/frontend/as2k_session.py" \
         "$RELEASE_ROOT/frontend/as2k_pcl_to_pdf.py" \
         "$RELEASE_ROOT/frontend/alphasmart_2000_shortcuts.txt" \
         "$RELEASE_ROOT/packaging/as2k-launcher.sh" \
         "$RELEASE_ROOT/packaging/as2k.desktop.in"; do
    [ -s "$f" ] || { echo "BLOCKED: missing Stable release resource $f"; exit 3; }
done
mkdir -p "$STAGE/usr/local/libexec/as2k/frontend" \
         "$STAGE/usr/local/bin" "$STAGE/usr/local/share/applications"
install -m 0755 "$BIN" "$STAGE/usr/local/libexec/as2k/as2k-bin"
for name in as2k_ui.py as2k_session.py as2k_pcl_to_pdf.py; do
    install -m 0755 "$RELEASE_ROOT/frontend/$name" "$STAGE/usr/local/libexec/as2k/frontend/$name"
done
install -m 0644 "$RELEASE_ROOT/frontend/alphasmart_2000_shortcuts.txt" \
    "$STAGE/usr/local/libexec/as2k/frontend/alphasmart_2000_shortcuts.txt"
install -m 0755 "$RELEASE_ROOT/packaging/as2k-launcher.sh" "$STAGE/usr/local/bin/as2k"
sed 's|@PREFIX@|/usr/local|g' "$RELEASE_ROOT/packaging/as2k.desktop.in" \
    > "$STAGE/usr/local/share/applications/as2k.desktop"
chmod 0644 "$STAGE/usr/local/share/applications/as2k.desktop"
PREFIX=/usr/local
RELFILES="libexec/as2k/as2k-bin
libexec/as2k/frontend/as2k_ui.py
libexec/as2k/frontend/as2k_session.py
libexec/as2k/frontend/as2k_pcl_to_pdf.py
libexec/as2k/frontend/alphasmart_2000_shortcuts.txt
bin/as2k
share/applications/as2k.desktop"
for relative in $RELFILES; do
    src="$STAGE/usr/local/$relative"
    [ -s "$src" ] || { echo "BLOCKED: missing staged $relative"; exit 3; }
    if [ -e "$PREFIX/$relative" ]; then
        mkdir -p "$BACKUP/$(dirname "$relative")"
        # The original Surf script used cp -p as an unprivileged user and
        # failed attempting to preserve root ownership. Back up exact bytes;
        # rollback reinstalls via sudo as root with explicit safe permissions.
        cp "$PREFIX/$relative" "$BACKUP/$relative"
    fi
done
restore() {
    for relative in $RELFILES; do
        if [ -f "$BACKUP/$relative" ]; then
            mode=0755
            case "$relative" in *.desktop|*.txt) mode=0644 ;; esac
            sudo -n install -o root -g root -m "$mode" "$BACKUP/$relative" "$PREFIX/$relative" || :
        else
            sudo -n rm -f "$PREFIX/$relative" || :
        fi
    done
}
STEP=INSTALL
finish() {
    rc=$?
    if [ "$rc" -ne 0 ] && [ "$STEP" = INSTALL ]; then restore; fi
    if [ "$rc" -eq 0 ]; then echo 'PASS INSTALLED_ARMV7' > "$WORK/status/install.status"
    else printf 'FAIL EXIT=%s STEP=%s\n' "$rc" "$STEP" > "$WORK/status/install.status"; fi
}
trap finish EXIT
# Create only missing installation directories with explicit traverse permissions.
# BusyBox install -d under umask 077 otherwise creates /usr/local/libexec
# without search permission for the normal desktop user.
for directory in "$PREFIX/libexec" "$PREFIX/libexec/as2k" "$PREFIX/libexec/as2k/frontend" "$PREFIX/bin" "$PREFIX/share" "$PREFIX/share/applications"; do
    [ ! -L "$directory" ] || { echo "BLOCKED: symlink directory: $directory"; exit 3; }
    if [ ! -d "$directory" ]; then
        [ ! -e "$directory" ] || { echo "BLOCKED: non-directory destination: $directory"; exit 3; }
        sudo -n install -d -m 0755 "$directory"
    fi
    [ -x "$directory" ] || { echo "BLOCKED: inaccessible destination directory: $directory"; exit 3; }
done
for relative in $RELFILES; do
    mode=0755
    case "$relative" in
        *.desktop|*.txt) mode=0644 ;;
    esac
    sudo -n install -m "$mode" "$STAGE/usr/local/$relative" "$PREFIX/$relative"
done
sudo -n "$PREFIX/libexec/as2k/as2k-bin" -validate
# No pycache write into root-owned /usr/local.
python3 -B -c 'import pathlib,sys; p=pathlib.Path(sys.argv[1]); compile(p.read_bytes(),str(p),"exec")' \
    "$PREFIX/libexec/as2k/frontend/as2k_ui.py"
python3 -B -c 'import pathlib,sys; p=pathlib.Path(sys.argv[1]); compile(p.read_bytes(),str(p),"exec")' \
    "$PREFIX/libexec/as2k/frontend/as2k_session.py"
STEP=READY
echo "SURFACE_INSTALL_PASS: native ARMv7 Stable core and GTK"
echo "BACKUP=$BACKUP"
echo "USER_DATA_UNTOUCHED (~/.config/as2k ~/.local/share/as2k)"
