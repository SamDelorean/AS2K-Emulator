#!/bin/sh
# AS2K Stable Reduced - VONTAR X3/HK1, Armbian ARM64
# Instalacion y compilacion VISIBLES, sin nohup ni tareas desacopladas.
# Build en SD (~ /Projects); binarios en /usr/local; ROMs privadas intactas.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODE=${1:---install}
case "$MODE" in --install|--check) ;; *) echo "Uso: sh install-as2k-vontar.sh [--check|--install]" >&2; exit 2 ;; esac

say() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nFAIL: %s\n' "$*" >&2; exit 1; }
as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

[ "$(uname -m)" = aarch64 ] || fail "Se requiere ARM64/aarch64 (VONTAR)"
[ -r /etc/os-release ] || fail "Falta /etc/os-release"
. /etc/os-release
case "${ID:-}:${VERSION_CODENAME:-}" in
    armbian:bookworm|debian:bookworm|armbian:trixie|debian:trixie) ;;
    *) fail "SO no previsto: ${ID:-?} ${VERSION_CODENAME:-?}" ;;
esac
[ -d "$HOME/Projects" ] || fail "Falta $HOME/Projects (SD); sin fallback a disco interno"
[ -d "$ROOT/.git" ] || fail "Ejecutar desde clon Git de AS2K-Emulator"
[ -z "$(git -C "$ROOT" status --porcelain)" ] || fail "Hay cambios locales AS2K; se preservan"
[ -f "$ROOT/scripts/build-stable-core.sh" ] || fail "Falta builder reducido"
[ -f "$ROOT/scripts/install-stable.sh" ] || fail "Falta instalador estable"

say "Fuente AS2K: $(git -C "$ROOT" rev-parse --short HEAD)"
sh "$ROOT/scripts/validate-stable-static.sh"
if [ "$MODE" = "--check" ]; then
    echo "PASS: validacion estatica. No se ha compilado ni instalado."
    exit 0
fi

MAME_REPO=https://github.com/SamDelorean/mame-as3k.git
MAME_SHA=1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b
MAME_ROOT="$HOME/Projects/alphasmart/as2k-stable-vontar/mame-as3k"
JOBS=${AS2K_JOBS:-1}
case "$JOBS" in ''|*[!0-9]*|0) fail "AS2K_JOBS debe ser entero positivo" ;; esac

say "Dependencias ARM64"
as_root apt-get update
as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates git build-essential make pkg-config python3 python3-gi \
    gir1.2-gtk-3.0 libsdl2-dev libsdl2-ttf-dev libfontconfig1-dev \
    libpulse-dev libasound2-dev libx11-dev libxinerama-dev libxi-dev \
    libxrandr-dev libxrender-dev libxext-dev libgl1-mesa-dev \
    libexpat1-dev zlib1g-dev libjpeg-dev libflac-dev libsqlite3-dev \
    libzstd-dev libarchive-dev ffmpeg cups-filters \
    desktop-file-utils xdg-user-dirs file binutils

if ! command -v startxfce4 >/dev/null 2>&1; then
    say "Instalando XFCE para interfaz grafica, sin modificar inicio automatico"
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        xfce4 xserver-xorg xinit dbus-x11
fi

say "Donante MAME fijo (reutilizar si ya existe)"
if [ ! -d "$MAME_ROOT/.git" ]; then
    [ ! -e "$MAME_ROOT" ] || fail "Ruta MAME ocupada: $MAME_ROOT"
    mkdir -p "$(dirname -- "$MAME_ROOT")"
    git clone --filter=blob:none --no-checkout "$MAME_REPO" "$MAME_ROOT"
    git -C "$MAME_ROOT" fetch --depth 1 origin "$MAME_SHA"
    git -C "$MAME_ROOT" checkout --detach "$MAME_SHA"
fi
[ "$(git -C "$MAME_ROOT" rev-parse HEAD)" = "$MAME_SHA" ] ||
    fail "Donante MAME no coincide; no se sobrescribira"
[ -z "$(git -C "$MAME_ROOT" status --porcelain)" ] ||
    fail "Donante MAME contiene modificaciones; no se sobrescribira"

say "Compilacion visible del nucleo reducido (make -j$JOBS)"
sh "$ROOT/scripts/build-stable-core.sh" "$MAME_ROOT" "$JOBS"
BIN="$ROOT/out/as2k-bin"
[ -x "$BIN" ] || fail "Falta el binario AS2K"
readelf -h "$BIN" | grep -Eq 'Machine:[[:space:]]*AArch64' ||
    fail "Se esperaba binario ARM64/AArch64"

say "Instalacion local en /usr/local"
as_root sh "$ROOT/scripts/install-stable.sh" "$BIN" /usr/local

DESKTOP="$HOME/Desktop"
[ -d "$HOME/Escritorio" ] && DESKTOP="$HOME/Escritorio"
mkdir -p "$DESKTOP"
cp /usr/local/share/applications/as2k.desktop "$DESKTOP/AS2K Emulator.desktop"
chmod 0755 "$DESKTOP/AS2K Emulator.desktop"

say "Pruebas finales"
 /usr/local/libexec/as2k/as2k-bin -validate
python3 -c 'import ast; ast.parse(open("/usr/local/libexec/as2k/frontend/as2k_ui.py", encoding="utf-8").read())'
[ -x /usr/local/bin/as2k ] || fail "Falta el comando as2k"
[ -f /usr/local/share/applications/as2k.desktop ] || fail "Falta la entrada de menu"

if [ -f "$HOME/.config/as2k/firmware.bin" ] &&
   [ -f "$HOME/.config/as2k/dictrom.bin" ]; then
    say "PASS: AS2K instalado; Firmware/DictROM disponibles"
else
    say "PASS: AS2K instalado; Firmware/DictROM pendientes en ~/.config/as2k/"
fi
echo "Abrir desde sesion grafica: as2k"
echo "ROM y DictROM privadas no fueron modificadas."
