#!/bin/sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
UI="$REPO_DIR/frontend/as2k_ui.py"

# Validate the source in memory: no __pycache__ or Git tree mutation.
python3 -B - "$UI" "$REPO_DIR/frontend/as2k_pcl_to_pdf.py" <<'PY_STATIC'
from pathlib import Path
import sys
for name in sys.argv[1:]:
    p=Path(name)
    compile(p.read_bytes(),str(p),"exec")
PY_STATIC

grep -q '^LCD_WIDTH = 240$' "$UI"
grep -q '^LCD_HEIGHT = 36$' "$UI"
grep -q '^VIDEO_FPS = 25$' "$UI"
grep -q '^IR_VISIBLE_BYTES = 64$' "$UI"
grep -q 'Atajos de teclado…' "$UI"
grep -q 'AS2K_UI_CONTROL_FILE' "$UI"
grep -q 'AS2K_UI_EVENT_FILE' "$UI"
test -s "$REPO_DIR/frontend/alphasmart_2000_shortcuts.txt"
test -s "$REPO_DIR/frontend/as2k_pcl_to_pdf.py"

printf '%s\n' "AS2K UI static validation: PASS"
