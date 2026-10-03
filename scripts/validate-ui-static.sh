#!/bin/sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
UI="$REPO_DIR/frontend/as2k_ui.py"

python3 -m py_compile "$UI"

grep -q '^LCD_WIDTH = 240$' "$UI"
grep -q '^LCD_HEIGHT = 36$' "$UI"
grep -q '^VIDEO_FPS = 25$' "$UI"
grep -q '^IR_VISIBLE_BYTES = 64 "$UI"
grep -q 'Atajos de teclado…' "$UI"
grep -q 'AS2K_UI_CONTROL_FILE' "$UI"
grep -q 'AS2K_UI_EVENT_FILE' "$UI"
test -s "$REPO_DIR/frontend/alphasmart_2000_shortcuts.txt"

printf '%s\n' "AS2K UI static validation: PASS"
