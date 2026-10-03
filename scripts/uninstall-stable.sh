#!/bin/sh
set -eu

PREFIX=${1:-/usr/local}

rm -f "$PREFIX/bin/as2k"
rm -f "$PREFIX/libexec/as2k/as2k-bin"
rm -rf "$PREFIX/libexec/as2k/frontend"
rmdir "$PREFIX/libexec/as2k" 2>/dev/null || true
rm -f "$PREFIX/share/applications/as2k.desktop"

echo "Removed AS2K stable program files from $PREFIX."
echo "User configuration, NVRAM, output and saved states were preserved."
