#!/bin/sh
set -eu

AS2K_REPO=${AS2K_REPO:-https://github.com/SamDelorean/AS2K-Emulator.git}
AS2K_BRANCH=${AS2K_BRANCH:-feature/as2k-stable-ui-r1}
MAME_REPO=${MAME_REPO:-https://github.com/SamDelorean/mame-as3k.git}
MAME_BRANCH=${MAME_BRANCH:-as2k-send-publication}
PREFIX=${AS2K_PREFIX:-/usr/local}
JOBS=${AS2K_JOBS:-1}
ASSUME_YES=${AS2K_ASSUME_YES:-0}

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

confirm()
{
    [ "$ASSUME_YES" = "1" ] && return 0
    printf '\nSe descargarán dependencias y fuentes, se compilará e instalará AS2K Emulator.\n'
    printf 'Continuar [s/N]? '
    IFS= read -r answer
    case "$answer" in
        s|S|si|SI|sí|Sí|y|Y|yes|YES) return 0 ;;
        *) echo "Instalación cancelada."; exit 0 ;;
    esac
}

run_sudo()
{
    if [ "$ASSUME_YES" = "1" ]; then
        sudo -n "$@" || die "sudo no está autorizado sin interacción"
    else
        sudo "$@"
    fi
}

case "$JOBS" in ''|*[!0-9]*|0) die "AS2K_JOBS debe ser un entero mayor que cero" ;; esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_ROOT=${AS2K_BUILD_DIR:-"$HOME/as2k-local-build"}
AS2K_SRC="$BUILD_ROOT/AS2K-Emulator"
MAME_SRC="$BUILD_ROOT/mame-as3k"
CONFIG_DIR=${XDG_CONFIG_HOME:-"$HOME/.config"}/as2k

find_image()
{
    variable=$1
    default_name=$2
    eval value=\${$variable:-}
    if [ -n "$value" ] && [ -f "$value" ]; then
        printf '%s' "$value"
        return 0
    fi
    if [ -f "$SCRIPT_DIR/$default_name" ]; then
        printf '%s' "$SCRIPT_DIR/$default_name"
        return 0
    fi
    return 1
}

say "AS2K Emulator — compilación e instalación local"

FIRMWARE=$(find_image AS2K_FIRMWARE AS2000_v3.1.4.bin || true)
DICTROM=$(find_image AS2K_DICTROM dictrom.bin || true)

if [ -z "$FIRMWARE" ]; then
    [ "$ASSUME_YES" = "1" ] && die "Modo automático: indique AS2K_FIRMWARE o coloque AS2000_v3.1.4.bin junto al SH"
    printf 'Ruta del firmware AS2000: '
    IFS= read -r FIRMWARE
fi
[ -f "$FIRMWARE" ] || die "No se encontró el firmware indicado"

if [ -z "$DICTROM" ]; then
    [ "$ASSUME_YES" = "1" ] && die "Modo automático: indique AS2K_DICTROM o coloque dictrom.bin junto al SH"
    printf 'Ruta de DictROM: '
    IFS= read -r DICTROM
fi
[ -f "$DICTROM" ] || die "No se encontró la DictROM indicada"

confirm

if [ "$ASSUME_YES" = "1" ]; then
    export GIT_TERMINAL_PROMPT=0
fi

say "Instalando dependencias necesarias"
if command -v apk >/dev/null 2>&1; then
    run_sudo apk add --no-progress \
        git build-base python3 py3-gobject3 gtk+3.0 ffmpeg cups cups-filters \
        sdl2-dev sdl2_ttf-dev fontconfig-dev pulseaudio-dev alsa-lib-dev \
        libxinerama-dev libxi-dev libxrandr-dev libxrender-dev libxext-dev \
        mesa-dev expat-dev
elif command -v apt-get >/dev/null 2>&1; then
    run_sudo apt-get update
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        git build-essential python3 python3-gi gir1.2-gtk-3.0 ffmpeg cups cups-filters \
        libsdl2-dev libsdl2-ttf-dev libfontconfig-dev libpulse-dev libasound2-dev \
        libxinerama-dev libxi-dev libxrandr-dev libxrender-dev libxext-dev libgl1-mesa-dev
else
    die "No se reconoce el gestor de paquetes (apk/apt-get)"
fi

say "Preparando fuentes"
mkdir -p "$BUILD_ROOT"

if [ -d "$AS2K_SRC/.git" ]; then
    [ -z "$(git -C "$AS2K_SRC" status --porcelain)" ] || die "$AS2K_SRC tiene cambios locales; no se tocará"
    git -C "$AS2K_SRC" fetch --depth 1 origin "$AS2K_BRANCH"
    git -C "$AS2K_SRC" checkout -B "$AS2K_BRANCH" FETCH_HEAD
else
    git clone --depth 1 --branch "$AS2K_BRANCH" "$AS2K_REPO" "$AS2K_SRC"
fi

if [ -d "$MAME_SRC/.git" ]; then
    [ -z "$(git -C "$MAME_SRC" status --porcelain)" ] || die "$MAME_SRC tiene cambios locales; no se tocará"
    git -C "$MAME_SRC" fetch --depth 1 origin "$MAME_BRANCH"
    git -C "$MAME_SRC" checkout -B "$MAME_BRANCH" FETCH_HEAD
else
    git clone --depth 1 --branch "$MAME_BRANCH" "$MAME_REPO" "$MAME_SRC"
fi

say "Validando fuentes antes de compilar"
sh "$AS2K_SRC/scripts/validate-stable-static.sh"

say "Compilando AS2K localmente (JOBS=$JOBS)"
sh "$AS2K_SRC/scripts/build-stable-core.sh" "$MAME_SRC" "$JOBS"

say "Instalando aplicación completa"
run_sudo sh "$AS2K_SRC/scripts/install-stable.sh" "$AS2K_SRC/out/as2k-bin" "$PREFIX"

say "Configurando firmware y DictROM privados"
mkdir -p "$CONFIG_DIR"
cp "$FIRMWARE" "$CONFIG_DIR/firmware.bin"
cp "$DICTROM" "$CONFIG_DIR/dictrom.bin"
chmod 600 "$CONFIG_DIR/firmware.bin" "$CONFIG_DIR/dictrom.bin"

say "Creando acceso directo"
DESKTOP_DIR=""
if command -v xdg-user-dir >/dev/null 2>&1; then
    DESKTOP_DIR=$(xdg-user-dir DESKTOP 2>/dev/null || true)
fi
if [ -z "$DESKTOP_DIR" ] || [ ! -d "$DESKTOP_DIR" ]; then
    for candidate in "$HOME/Desktop" "$HOME/Escritorio"; do
        if [ -d "$candidate" ]; then DESKTOP_DIR=$candidate; break; fi
    done
fi
if [ -n "$DESKTOP_DIR" ] && [ -d "$DESKTOP_DIR" ]; then
    cp "$PREFIX/share/applications/as2k.desktop" "$DESKTOP_DIR/AS2K Emulator.desktop"
    chmod +x "$DESKTOP_DIR/AS2K Emulator.desktop"
    if command -v gio >/dev/null 2>&1; then
        gio set "$DESKTOP_DIR/AS2K Emulator.desktop" metadata::trusted true >/dev/null 2>&1 || true
    fi
    printf 'Escritorio: %s\n' "$DESKTOP_DIR/AS2K Emulator.desktop"
else
    printf 'No se encontró carpeta Escritorio; el acceso del menú sí quedó instalado.\n'
fi

say "Comprobación final"
"$PREFIX/libexec/as2k/as2k-bin" -validate
python3 -m py_compile "$PREFIX/libexec/as2k/frontend/as2k_ui.py"
[ -x "$PREFIX/bin/as2k" ] || die "Falta el lanzador instalado"
[ -f "$PREFIX/share/applications/as2k.desktop" ] || die "Falta el acceso del menú"

printf '\nINSTALACIÓN AS2K: PASS\n'
printf 'Comando: %s/bin/as2k\n' "$PREFIX"
printf 'Menú: AS2K Emulator\n'
printf 'Fuentes/build conservados en: %s\n' "$BUILD_ROOT"
printf '\nPara iniciar ahora: %s/bin/as2k\n' "$PREFIX"
