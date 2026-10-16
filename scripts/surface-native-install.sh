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
# Stage installation without touching /usr/local or user NVRAM.
sh "$AS2K/scripts/install-stable.sh" "$BIN" "$STAGE/usr/local"
# Re-root desktop Exec/TryExec to final /usr/local.
sed -i "s|$STAGE/usr/local|/usr/local|g" "$STAGE/usr/local/share/applications/as2k.desktop"
PREFIX=/usr/local
RELFILES="libexec/as2k/as2k-bin
libexec/as2k/frontend/as2k_ui.py
libexec/as2k/frontend/as2k_pcl_to_pdf.py
libexec/as2k/frontend/alphasmart_2000_shortcuts.txt
bin/as2k
share/applications/as2k.desktop"
for relative in $RELFILES; do
    src="$STAGE/usr/local/$relative"
    [ -s "$src" ] || { echo "BLOCKED: missing staged $relative"; exit 3; }
    if [ -e "$PREFIX/$relative" ]; then
        mkdir -p "$BACKUP/$(dirname "$relative")"
        cp -p "$PREFIX/$relative" "$BACKUP/$relative"
    fi
done
restore() {
    for relative in $RELFILES; do
        if [ -f "$BACKUP/$relative" ]; then
            sudo -n cp -p "$BACKUP/$relative" "$PREFIX/$relative" || :
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
for relative in $RELFILES; do
    sudo -n install -d "$PREFIX/$(dirname "$relative")"
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
STEP=READY
echo "SURFACE_INSTALL_PASS: native ARMv7 Stable core and GTK"
echo "BACKUP=$BACKUP"
echo "USER_DATA_UNTOUCHED (~/.config/as2k ~/.local/share/as2k)"
