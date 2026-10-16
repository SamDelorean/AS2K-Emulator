#!/bin/sh
# AS2K Stable ARM64: reproducible incremental update; no firmware or user-data changes.
set -eu
REF=36996b91053969661371dc067d49026fab367a47
PREFIX=${AS2K_PREFIX:-/usr/local}
SOURCE=${AS2K_SOURCE:-}
MAME=${AS2K_MAME_TREE:-}
JOBS=${AS2K_JOBS:-1}
LOG=${AS2K_UPDATE_LOG:-"$HOME/as2k-stable-bootstrap-update.log"}
say(){ printf '%s\n' "$*" | tee -a "$LOG"; }
fail(){ say "FAIL: $*"; exit 1; }
[ -n "$SOURCE" ] && [ -d "$SOURCE/.git" ] || fail "Set AS2K_SOURCE to existing Git clone"
[ -n "$MAME" ] && [ -d "$MAME/.git" ] || fail "Set AS2K_MAME_TREE to existing MAME donor clone"
[ "$(uname -m)" = aarch64 ] || fail "Target must be aarch64"
[ "$(id -u)" -ne 0 ] || fail "Run as normal user with passwordless sudo"
sudo -n true || fail "Noninteractive sudo unavailable"
case "$JOBS" in ''|*[!0-9]*|0) fail "Invalid AS2K_JOBS" ;; esac
SOURCE=$(cd "$SOURCE" && pwd)
MAME=$(cd "$MAME" && pwd)
# The existing source checkout may contain preserved local work.
# Read only Git objects; never checkout, reset, clean, clone, or modify its index.
if ! git -C "$SOURCE" cat-file -e "$REF^{commit}" 2>/dev/null; then
    git -C "$SOURCE" fetch --no-tags origin feature/stable-payload-auto-boot-b3-20261015 ||
        fail "Unable to fetch approved branch"
    git -C "$SOURCE" cat-file -e "$REF^{commit}" 2>/dev/null ||
        fail "Pinned revision not available in local Git history"
fi
[ -f "$MAME/src/mame/skeleton/alphasma.cpp" ] || fail "Incompatible donor tree"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/as2k-vontar-update.XXXXXXXX")
BACKUP="$WORK/backup"
mkdir -p "$BACKUP"
INST="$PREFIX/libexec/as2k"
mkdir -p "$WORK/src"
rollback(){
    [ ! -f "$BACKUP/as2k-bin" ] || sudo -n cp -p "$BACKUP/as2k-bin" "$INST/as2k-bin"
    [ ! -f "$BACKUP/as2k_ui.py" ] || sudo -n cp -p "$BACKUP/as2k_ui.py" "$INST/frontend/as2k_ui.py"
}
cleanup(){ rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM
git -C "$SOURCE" archive "$REF" | tar -x -C "$WORK/src" || fail "Pinned revision archive extraction failed"
say "SOURCE_PIN=$REF"
sh -n "$WORK/src/scripts/build-stable-core.sh" || fail "Shell syntax"
python3 -m py_compile "$WORK/src/frontend/as2k_ui.py" || fail "GTK Python syntax"
sh "$WORK/src/scripts/validate-stable-static.sh" || fail "Static gate"
say "STATIC_PASS"
# Existing donor objects are reused by make unless changed; no clean is issued.
sh "$WORK/src/scripts/build-stable-core.sh" "$MAME" "$JOBS" || fail "Incremental build"
[ -x "$WORK/src/out/as2k-bin" ] || fail "Built binary absent"
"$WORK/src/out/as2k-bin" -validate || fail "MAME validation"
say "BUILD_PASS"
# Preserve system installation for rollback. Never touch XDG private data.
[ -x "$INST/as2k-bin" ] || fail "Existing installed AS2K core missing"
[ -f "$INST/frontend/as2k_ui.py" ] || fail "Existing installed GTK missing"
cp -p "$INST/as2k-bin" "$BACKUP/as2k-bin"
cp -p "$INST/frontend/as2k_ui.py" "$BACKUP/as2k_ui.py"
if ! sudo -n install -m 0755 "$WORK/src/out/as2k-bin" "$INST/as2k-bin" ||
   ! sudo -n install -m 0755 "$WORK/src/frontend/as2k_ui.py" "$INST/frontend/as2k_ui.py"; then
    rollback
    fail "Install failed; core and GTK restored"
fi
if ! "$PREFIX/libexec/as2k/as2k-bin" -validate || ! python3 -m py_compile "$INST/frontend/as2k_ui.py"; then
    rollback
    fail "Installed validation failed; core and GTK restored"
fi
say "INSTALLED_PASS_GUI_FUNCTIONAL_PENDING"
