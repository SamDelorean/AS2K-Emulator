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
sh -n "$ROOT/scripts/uninstall-stable.sh"
sh -n "$ROOT/scripts/build-stable-core.sh"
sh -n "$ROOT/scripts/test-ui-send-runtime.sh"
sh -n "$ROOT/scripts/test-ui-print-runtime.sh"
sh -n "$ROOT/scripts/test-ui-ir-runtime.sh"
sh -n "$ROOT/scripts/test-ui-keyboard-runtime.sh"
python3 -m py_compile "$ROOT/scripts/patch-mc68hc11-pai.py"
sh "$ROOT/scripts/validate-ui-static.sh"

grep -F '@PREFIX@/bin/as2k' "$ROOT/packaging/as2k.desktop.in" >/dev/null \
    || fail "desktop template does not target installed stable launcher"

for required in \
    "$ROOT/frontend/as2k_ui.py" \
    "$ROOT/frontend/as2k_pcl_to_pdf.py" \
    "$ROOT/frontend/alphasmart_2000_shortcuts.txt"
do
    [ -s "$required" ] || fail "missing installed frontend resource: $required"
done

grep -F 'python3 "$AS2K_UI"' "$ROOT/packaging/as2k-launcher.sh" >/dev/null \
    || fail "stable launcher does not start GTK frontend"
grep -F 'KEYDOWN ' "$DRIVER" >/dev/null \
    || fail "ordinary keyboard bridge missing in core"
grep -F 'key-press-event' "$ROOT/frontend/as2k_ui.py" >/dev/null \
    || fail "ordinary keyboard bridge missing in GTK frontend"

echo "AS2K stable static installation gate: PASS"
