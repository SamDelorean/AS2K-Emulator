#!/bin/sh
set -eu

usage()
{
    echo "Usage: $0 BUILT_BINARY [PREFIX]" >&2
    echo "  BUILT_BINARY  validated reduced AS2K executable" >&2
    echo "  PREFIX        installation prefix (default: /usr/local)" >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    exit 2
fi

BINARY=$1
PREFIX=${2:-/usr/local}

if [ ! -f "$BINARY" ] || [ ! -x "$BINARY" ]; then
    echo "Not an executable file: $BINARY" >&2
    exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

LIBEXEC_DIR="$PREFIX/libexec/as2k"
BIN_DIR="$PREFIX/bin"
APP_DIR="$PREFIX/share/applications"

install -d "$LIBEXEC_DIR" "$BIN_DIR" "$APP_DIR"
install -m 0755 "$BINARY" "$LIBEXEC_DIR/as2k-bin"
install -m 0755 "$REPO_DIR/packaging/as2k-launcher.sh" "$BIN_DIR/as2k"

ESCAPED_PREFIX=$(printf '%s' "$PREFIX" | sed 's/[&|]/\\&/g')
sed "s|@PREFIX@|$ESCAPED_PREFIX|g" "$REPO_DIR/packaging/as2k.desktop.in" \
    > "$APP_DIR/as2k.desktop"
chmod 0644 "$APP_DIR/as2k.desktop"

echo "Installed AS2K stable:"
echo "  command: $BIN_DIR/as2k"
echo "  binary:  $LIBEXEC_DIR/as2k-bin"
echo "  menu:    $APP_DIR/as2k.desktop"
echo
echo "Firmware and DictROM are not installed."
echo "AS2K will request user-supplied images through the emulator file UI."
