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
sh -n "$ROOT/scripts/uninstall-stable.sh"

grep -F '@PREFIX@/bin/as2k' "$ROOT/packaging/as2k.desktop.in" >/dev/null \
    || fail "desktop template does not target installed stable launcher"

echo "AS2K stable static installation gate: PASS"
