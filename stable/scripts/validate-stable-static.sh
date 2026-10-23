#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DRIVER="$ROOT/src/mame/skeleton/alphasma.cpp"

fail()
{
    echo "FAIL: $*" >&2
    exit 1
}

[ -f "$DRIVER" ] || fail "missing AS2K driver"

for forbidden in \
    'alphasmart__2000__v3.1.4' \
    'alphasmart__2000__v3.0.8' \
    'dictrom__v1' \
    'ROMX_LOAD' \
    'ROM_SYSTEM_BIOS' \
    'machine().options().media_path()'
do
    if grep -F "$forbidden" "$DRIVER" >/dev/null; then
        fail "public stable driver still contains forbidden fixed-ROM/runtime-path token: $forbidden"
    fi
done

for required in \
    'GENERIC_SOCKET(config, m_firmware' \
    'GENERIC_SOCKET(config, m_dictrom' \
    'm_firmware->set_must_be_loaded(true)' \
    'm_dictrom->set_must_be_loaded(true)' \
    'machine().options().snapshot_directory()'
do
    grep -F "$required" "$DRIVER" >/dev/null || fail "missing stable contract token: $required"
done

sh -n "$ROOT/packaging/as2k-launcher.sh"
sh -n "$ROOT/scripts/install-stable.sh"
sh -n "$ROOT/scripts/install-surface-local.sh"
sh -n "$ROOT/install-as2k.sh"
sh -n "$ROOT/install-as2k-surface.sh"
sh -n "$ROOT/scripts/uninstall-stable.sh"
sh -n "$ROOT/scripts/build-stable-core.sh"
sh -n "$ROOT/scripts/test-ui-send-runtime.sh"
sh -n "$ROOT/scripts/test-ui-print-runtime.sh"
sh -n "$ROOT/scripts/test-ui-ir-runtime.sh"
sh -n "$ROOT/scripts/test-ui-keyboard-runtime.sh"
# Read-only syntax validation: the legacy py_compile command dirtied Git.
python3 -B - "$ROOT/scripts/patch-mc68hc11-pai.py" "$ROOT/scripts/patch-mc68hc11-bootstrap.py" <<'PY_STATIC'
from pathlib import Path
import sys
for name in sys.argv[1:]:
    p=Path(name)
    compile(p.read_bytes(),str(p),"exec")
PY_STATIC
sh "$ROOT/scripts/validate-ui-static.sh"

# Gate future Stable installations against the no-op 100/150/200% menu.
# Headless AST-based test exercises actual GTK drawing/selection methods.
python3 -B "$ROOT/tests/test_view_scale.py"
# Preserve the user-approved centered 2x8 key layout and physical Escape.
python3 -B "$ROOT/tests/test_virtual_button_rows.py"

grep -F '@PREFIX@/bin/as2k' "$ROOT/packaging/as2k.desktop.in" >/dev/null \
    || fail "desktop template does not target installed stable launcher"

for required in \
    "$ROOT/frontend/as2k_ui.py" \
    "$ROOT/frontend/as2k_session.py" \
    "$ROOT/frontend/as2k_pcl_to_pdf.py" \
    "$ROOT/frontend/alphasmart_2000_shortcuts.txt"
do
    [ -s "$required" ] || fail "missing installed frontend resource: $required"
done

[ -s "$ROOT/frontend/as2k_session.py" ] || fail "VONTAR session manager missing"
python3 -B - "$ROOT/frontend/as2k_session.py" <<'PY_SESSION_SYNTAX'
import pathlib, sys
source = pathlib.Path(sys.argv[1])
compile(source.read_bytes(), str(source), 'exec')
PY_SESSION_SYNTAX
grep -F 'exec python3 /usr/local/libexec/as2k/frontend/as2k_session.py "$@"' "$ROOT/packaging/as2k-launcher.sh" >/dev/null \
    || fail "VONTAR stable launcher does not exec canonical session manager"
grep -F 'class ManagedWindow(ui.AS2KWindow):' "$ROOT/frontend/as2k_session.py" >/dev/null \
    || fail "VONTAR session UI extension missing"
grep -F 'SDL_VIDEODRIVER' "$ROOT/frontend/as2k_session.py" >/dev/null \
    || fail "VONTAR integrated display driver selection missing"
grep -F 'def update_boot_cfg(self):' "$ROOT/frontend/as2k_session.py" >/dev/null \
    || fail "VONTAR persistent boot mode support missing"
grep -F 'KEYDOWN ' "$DRIVER" >/dev/null \
    || fail "ordinary keyboard bridge missing in core"
grep -F 'key-press-event' "$ROOT/frontend/as2k_ui.py" >/dev/null \
    || fail "ordinary keyboard bridge missing in GTK frontend"

grep -F 'stage_image_file' "$DRIVER" >/dev/null \
    || fail "manual-reset ROM/DictROM staging bridge missing"
grep -F 'm_pending_firmware_valid' "$DRIVER" >/dev/null \
    || fail "pending Firmware reset gate missing"
grep -F 'm_pending_dictrom_valid' "$DRIVER" >/dev/null \
    || fail "pending DictROM reset gate missing"

for forbidden_power in 'KEY POWER' 'MACHINE POWER' 'Encender / apagar' '("Power",'; do
    if grep -F "$forbidden_power" "$DRIVER" "$ROOT/frontend/as2k_ui.py" "$ROOT/frontend/README.md" "$ROOT/docs/UI_CONTRACT.md" >/dev/null; then
        fail "stable UI/core still exposes removed Power control: $forbidden_power"
    fi
done

echo "AS2K stable static installation gate: PASS"
