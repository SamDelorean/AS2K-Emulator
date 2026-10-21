#!/usr/bin/env bash
# AS2K Vontar, one bounded incremental recovery from exact pristine HC11 donor.
# Does not rebuild MAME tree or reinstall GTK. On failure keeps rollback sources.
set -Eeuo pipefail; umask 077
TREE="$HOME/projects/mame-as2k-stable-arm64"
LOGROOT="$HOME/.local/share/alphasmart/deploy-logs/AS2K_VONTAR_PC_WAKEUP_20261021"
SRC="$TREE/src/mame/skeleton/alphasma.cpp"
CPP="$TREE/src/devices/cpu/mc68hc11/mc68hc11.cpp"
HEADER="$TREE/src/devices/cpu/mc68hc11/mc68hc11.h"
TARGET="/usr/local/libexec/as2k/as2k-bin"
PIN="fix/pc-host-wakeup-20261020"
URI="https://raw.githubusercontent.com/SamDelorean/AS2K-Emulator"
mkdir -p "$LOGROOT/recovery" "$LOGROOT/rollback"
exec > >(tee -a "$LOGROOT/resume.log") 2>&1
STEP=INIT
finish() {
  rc=$?
  trap - EXIT
  printf 'TASK=AS2K_VONTAR_PC_WAKEUP_RESUME\nSTEP=%s\nEXIT=%s\n' "$STEP" "$rc" >"$LOGROOT/resume.status"
  echo "AS2K_VONTAR_RESUME result=$rc step=$STEP"
  exit "$rc"
}
trap finish EXIT
test "$(uname -m)" = aarch64 && sudo -n true
test -x "$TARGET" && test -f "$TREE/makefile" && test -f "$CPP" && test -f "$HEADER"
test ! -L "$TREE" && test ! -L "$CPP" && test ! -L "$HEADER"
STEP=FETCH_CANONICAL_AS2K_CPU_PATCHERS
for name in patch-mc68hc11-pai.py patch-mc68hc11-bootstrap.py; do
 curl -fLsS --retry 2 --connect-timeout 20 "$URI/$PIN/scripts/$name" -o "$LOGROOT/recovery/$name"
done
python3 -m py_compile "$LOGROOT/recovery/"*.py
STEP=VERIFY_OR_PATCH_HC11
CPP_GIT=$(git hash-object "$CPP")
HDR_GIT=$(git hash-object "$HEADER")
if grep -q MC68HC11_PAI_LINE "$HEADER" && grep -q diag_bootstrap_load "$HEADER" && grep -q as2k_ir_tx_callback "$HEADER"; then
 echo "AS2K CPU already contains PAI + bootstrap + IR callbacks"
elif [ "$CPP_GIT" = 375c6e1c2a2f74912661da8dc659e23dfcb44f02 ] &&
     [ "$HDR_GIT" = a7248de563b572aa586b28a8493ddd087dfbb400 ]; then
 cp -p "$CPP" "$LOGROOT/rollback/mc68hc11.cpp.before-pai"
 cp -p "$HEADER" "$LOGROOT/rollback/mc68hc11.h.before-pai"
 python3 "$LOGROOT/recovery/patch-mc68hc11-pai.py" "$TREE"
else
 echo "BLOCKED_UNEXPECTED_HC11_CPU_SHA cpp=$CPP_GIT h=$HDR_GIT"; exit 4
fi
test -f "$LOGROOT/alphasma.pc-wakeup.cpp"
test "$(git hash-object "$LOGROOT/alphasma.pc-wakeup.cpp")" = d592f7a9b37234f4b12f1806eaca361248b40d22
cmp -s "$LOGROOT/alphasma.pc-wakeup.cpp" "$SRC" || cp "$LOGROOT/alphasma.pc-wakeup.cpp" "$SRC"
STEP=BUILD_INCREMENTAL
cd "$TREE"
# 2 jobs; previously assembled libraries and generated gmake preserved.
make -j2 SUBTARGET=as2k SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 USE_QTDEBUG=0
test -x "$TREE/as2k"
STEP=VALIDATE
"$TREE/as2k" -validate
file "$TREE/as2k" | grep -qi aarch64
sha256sum "$TREE/as2k" >"$LOGROOT/resume.binary.sha256"
STEP=ATOMIC_INSTALL
[ -s "$LOGROOT/rollback/as2k-bin.before-pc-wakeup" ] ||
 cp -p "$TARGET" "$LOGROOT/rollback/as2k-bin.before-pc-wakeup"
sudo -n install -m 0755 "$TREE/as2k" "$TARGET.next"
sudo -n mv -f "$TARGET.next" "$TARGET"
cmp -s "$TREE/as2k" "$TARGET"
STEP=PASS
echo "AS2K_VONTAR_PC_WAKEUP_INCREMENTAL_PASS"
