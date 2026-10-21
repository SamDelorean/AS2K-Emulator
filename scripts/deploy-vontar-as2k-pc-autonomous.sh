#!/usr/bin/env bash
# Autonomous minimal Vontar AS2K PC-wakeup core update, no GUI interruption.
set -Eeuo pipefail
umask 077
TAG="AS2K_VONTAR_PC_WAKEUP_20261021"
OUT="$HOME/.local/share/alphasmart/deploy-logs/$TAG"
TREE="$HOME/projects/mame-as2k-stable-arm64"
BIN="/usr/local/libexec/as2k/as2k-bin"
SRC="$TREE/src/mame/skeleton/alphasma.cpp"
DONOR_SHA="d592f7a9b37234f4b12f1806eaca361248b40d22"
URL="https://raw.githubusercontent.com/SamDelorean/AS2K-Emulator/fix/pc-host-wakeup-20261020/src/mame/skeleton/alphasma.cpp"
REMOTE="googledrive:AS2K_TEMP/DEPLOY_20261021"
mkdir -p "$OUT"
exec > >(tee -a "$OUT/run.log") 2>&1
STEP=PREFLIGHT
finish(){
    local rc=$?
    trap - EXIT
    printf 'TASK=%s\nHOST=%s\nSTEP=%s\nEXIT=%s\n' "$TAG" "$(hostname)" "$STEP" "$rc" >"$OUT/status.txt"
    for f in status.txt run.log old.sha256 new.sha256; do
        [ ! -f "$OUT/$f" ] || rclone copyto "$OUT/$f" "$REMOTE/$TAG-$f" --retries 1 --timeout 90s ||
            echo "Drive upload unavailable for $f"
    done
    echo "$TAG RESULT=$rc STEP=$STEP"
    exit "$rc"
}
trap finish EXIT
[ "$(uname -m)" = aarch64 ] || { echo "BLOCKED wrong architecture"; exit 2; }
sudo -n true || { echo "BLOCKED passwordless sudo"; exit 2; }
[ -f "$TREE/makefile" ] && [ -f "$SRC" ] && [ -x "$BIN" ] || {
    echo "BLOCKED existing incremental MAME tree / installed core missing"; exit 3;
}
[ ! -L "$TREE" ] && [ ! -L "$SRC" ] && [ ! -L "$BIN" ] || {
    echo "BLOCKED unexpected symlink"; exit 3;
}
test -e /usr/local/libexec/as2k/frontend/as2k_ui.py || {
    echo "BLOCKED existing reduced AS2K frontend missing"; exit 3;
}
STEP=FETCH_SINGLE_DRIVER
curl -fLsS --connect-timeout 15 --max-time 90 "$URL" -o "$OUT/alphasma.pc-wakeup.cpp"
[ "$(git hash-object "$OUT/alphasma.pc-wakeup.cpp")" = "$DONOR_SHA" ] ||
    { echo "BLOCKED unexpected donor SHA"; exit 4; }
sha256sum "$BIN" > "$OUT/old.sha256"
if cmp -s "$OUT/alphasma.pc-wakeup.cpp" "$SRC"; then
    echo "Driver already current"
else
    cp -a "$SRC" "$OUT/alphasma.original.cpp"
    cp "$OUT/alphasma.pc-wakeup.cpp" "$SRC"
fi
STEP=BUILD_INCREMENTAL
cd "$TREE"
make -j2 SUBTARGET=as2k SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 USE_QTDEBUG=0
[ -x "$TREE/as2k" ] || { echo "BLOCKED no reduced AS2K binary"; exit 5; }
STEP=VALIDATE
"$TREE/as2k" -validate
file "$TREE/as2k"
file "$TREE/as2k" | grep -qi 'aarch64\|arm aarch64' || { echo "BLOCKED wrong ELF architecture"; exit 5; }
STEP=INSTALL_ATOMIC
mkdir -p "$OUT/rollback"
cp -p "$BIN" "$OUT/rollback/as2k-bin.before-pc-wakeup"
sudo -n install -m 0755 "$TREE/as2k" /usr/local/libexec/as2k/as2k-bin.next
sudo -n mv -f /usr/local/libexec/as2k/as2k-bin.next "$BIN"
sha256sum "$BIN" > "$OUT/new.sha256"
cmp -s "$TREE/as2k" "$BIN" || { echo "FAIL installed binary differs"; exit 6; }
STEP=COMPLETE
echo "PASS incremental AS2K PC host wakeup; GTK frontend unchanged; rollback preserved"
