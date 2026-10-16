#!/bin/sh
# Optional source staging on Surface, with exact commit pins and no overwrites.
# Private GitHub repositories require preconfigured authentication.
set -eu
umask 077
[ "$(uname -m)" = armv7l ] || { echo "BLOCKED: target not Surface ARMv7"; exit 2; }
WORK="$HOME/Projects/alphasmart/as2k-surf-native"
mkdir -p "$WORK/sources" "$WORK/status"
STATUS="$WORK/status/sources.status"
STEP=START
finish() {
    rc=$?
    if [ "$rc" -eq 0 ]; then echo 'PASS SOURCES_PINNED' > "$STATUS"
    else printf 'FAIL EXIT=%s STEP=%s\n' "$rc" "$STEP" > "$STATUS"; fi
}
trap finish EXIT
export GIT_TERMINAL_PROMPT=0
# Exactly the code installed and tested on VONTAR, not subsequent UX notes.
AS2K_PIN=36996b91053969661371dc067d49026fab367a47
MAME_PIN=1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b
AS2K_URL=https://github.com/SamDelorean/AS2K-Emulator.git
MAME_URL=https://github.com/SamDelorean/mame-as3k.git

stage() {
    name=$1; url=$2; pin=$3
    dest="$WORK/sources/$name"
    if [ -e "$dest" ]; then
        [ -d "$dest/.git" ] || { echo "BLOCKED: non-Git source $dest"; return 4; }
        actual=$(git -C "$dest" rev-parse HEAD)
        [ "$actual" = "$pin" ] || { echo "BLOCKED: existing source revision mismatch $name"; return 4; }
        git -C "$dest" diff --quiet && git -C "$dest" diff --cached --quiet ||
            { echo "BLOCKED: source has local modifications $name"; return 4; }
        echo "REUSED_PINNED_SOURCE $name $actual"
        return 0
    fi
    # No local source was present in the verified Surface baseline.
    # Create a uniquely owned scratch clone; move it only after pin verification.
    tmp=$(mktemp -d "$WORK/sources/.source-stage-XXXXXXXX")
    if ! (
        git -C "$tmp" init -q &&
        git -C "$tmp" remote add origin "$url" &&
        git -C "$tmp" fetch --no-tags --depth 1 origin "$pin" &&
        git -C "$tmp" checkout --detach -q FETCH_HEAD &&
        [ "$(git -C "$tmp" rev-parse HEAD)" = "$pin" ]
    ); then
        rm -rf "$tmp"
        echo "BLOCKED: failed to obtain exact private source $name (no fallback commit)"
        return 4
    fi
    mv "$tmp" "$dest"
    echo "FETCHED_PINNED_SOURCE $name $pin"
}
STEP=AS2K
stage AS2K-Emulator "$AS2K_URL" "$AS2K_PIN"
STEP=MAME
stage mame-as3k "$MAME_URL" "$MAME_PIN"
STEP=READY
echo "SOURCE_STAGE_PASS: pinned VONTAR Stable core + MAME donor"
