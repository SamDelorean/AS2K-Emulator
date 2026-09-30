#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PREFIX=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)
AS2K_BIN="$PREFIX/libexec/as2k/as2k-bin"

if [ ! -x "$AS2K_BIN" ]; then
    echo "AS2K stable binary not found: $AS2K_BIN" >&2
    exit 127
fi

CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}

AS2K_CONFIG="$CONFIG_HOME/as2k"
AS2K_DATA="$DATA_HOME/as2k"
AS2K_STATE="$STATE_HOME/as2k"

mkdir -p \
    "$AS2K_CONFIG/cfg" \
    "$AS2K_DATA/nvram" \
    "$AS2K_DATA/output" \
    "$AS2K_STATE/states"

echo "Starting AS2K stable" >&2

exec "$AS2K_BIN" asma2k \
    -cfg_directory "$AS2K_CONFIG/cfg" \
    -nvram_directory "$AS2K_DATA/nvram" \
    -snapshot_directory "$AS2K_DATA/output" \
    -state_directory "$AS2K_STATE/states" \
    "$@"
