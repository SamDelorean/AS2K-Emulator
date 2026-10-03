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
FRONTEND_DIR="$LIBEXEC_DIR/frontend"
BIN_DIR="$PREFIX/bin"
APP_DIR="$PREFIX/share/applications"

for required in \
    "$REPO_DIR/frontend/as2k_ui.py" \
    "$REPO_DIR/frontend/as2k_pcl_to_pdf.py" \
    "$REPO_DIR/frontend/alphasmart_2000_shortcuts.txt" \
    "$REPO_DIR/packaging/as2k-launcher.sh" \
    "$REPO_DIR/packaging/as2k.desktop.in"
do
    [ -f "$required" ] || { echo "Missing installation resource: $required" >&2; exit 2; }
done

install -d "$LIBEXEC_DIR" "$FRONTEND_DIR" "$BIN_DIR" "$APP_DIR"
install -m 0755 "$BINARY" "$LIBEXEC_DIR/as2k-bin"
install -m 0755 "$REPO_DIR/frontend/as2k_ui.py" "$FRONTEND_DIR/as2k_ui.py"
install -m 0755 "$REPO_DIR/frontend/as2k_pcl_to_pdf.py" "$FRONTEND_DIR/as2k_pcl_to_pdf.py"
install -m 0644 "$REPO_DIR/frontend/alphasmart_2000_shortcuts.txt" "$FRONTEND_DIR/alphasmart_2000_shortcuts.txt"
install -m 0755 "$REPO_DIR/packaging/as2k-launcher.sh" "$BIN_DIR/as2k"

ESCAPED_PREFIX=$(printf '%s' "$PREFIX" | sed 's/[&|]/\\&/g')
sed "s|@PREFIX@|$ESCAPED_PREFIX|g" "$REPO_DIR/packaging/as2k.desktop.in" \
    > "$APP_DIR/as2k.desktop"
chmod 0644 "$APP_DIR/as2k.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "Installed AS2K Emulator:"
echo "  command:   $BIN_DIR/as2k"
echo "  core:      $LIBEXEC_DIR/as2k-bin"
echo "  frontend:  $FRONTEND_DIR/as2k_ui.py"
echo "  menu:      $APP_DIR/as2k.desktop"
echo
echo "Configure user-supplied images as:"
echo "  ~/.config/as2k/firmware.bin"
echo "  ~/.config/as2k/dictrom.bin"
echo "or set AS2K_FIRMWARE / AS2K_DICTROM."
