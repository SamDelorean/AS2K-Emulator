#!/bin/sh
set -eu

# AS2K Emulator — unattended Surface RT/postmarketOS installer.
# Stable source revisions are frozen to the version already built/installed on T640.
AS2K_REPO="https://github.com/SamDelorean/AS2K-Emulator.git"
AS2K_COMMIT="8c2d34624c280cbc3c9d4e9df4a52ac039e41b9c"
MAME_REPO="https://github.com/SamDelorean/mame-as3k.git"
MAME_COMMIT="1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b"
PREFIX=${AS2K_PREFIX:-/usr/local}
JOBS=${AS2K_JOBS:-1}

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

case "$JOBS" in
    ''|*[!0-9]*|0) die "AS2K_JOBS debe ser un entero mayor que cero" ;;
esac

[ -x /sbin/apk ] || command -v apk >/dev/null 2>&1 ||
    die "Este instalador es para postmarketOS/Alpine (apk no encontrado)"

if [ -n "${AS2K_USER:-}" ]; then
    TARGET_USER=$AS2K_USER
elif id spc >/dev/null 2>&1; then
    TARGET_USER=spc
elif [ "$(id -u)" -ne 0 ]; then
    TARGET_USER=$(id -un)
elif [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
    TARGET_USER=$SUDO_USER
else
    die "No se pudo determinar el usuario destino; use AS2K_USER=<usuario>"
fi

TARGET_HOME=$(awk -F: -v u="$TARGET_USER" '$1 == u { print $6; exit }' /etc/passwd)
[ -n "$TARGET_HOME" ] || die "No se encontró HOME para $TARGET_USER"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_ROOT=${AS2K_BUILD_DIR:-"$TARGET_HOME/as2k-local-build"}
AS2K_SRC="$BUILD_ROOT/AS2K-Emulator"
MAME_SRC="$BUILD_ROOT/mame-as3k"
CONFIG_DIR="$TARGET_HOME/.config/as2k"
STATUS_FILE="$TARGET_HOME/as2k-install-surface.status"

priv()
{
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo -n "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas -n "$@"
    else
        die "Se requieren privilegios root sin interacción"
    fi
}

finish()
{
    rc=$?
    trap - EXIT
    if [ "$(id -u)" -eq 0 ]; then
        [ -d "$BUILD_ROOT" ] && chown -R "$TARGET_USER" "$BUILD_ROOT" 2>/dev/null || true
        [ -d "$CONFIG_DIR" ] && chown -R "$TARGET_USER" "$CONFIG_DIR" 2>/dev/null || true
    fi
    if [ "$rc" -eq 0 ]; then
        {
            echo "PASS"
            echo "AS2K_COMMIT=$AS2K_COMMIT"
            echo "MAME_COMMIT=$MAME_COMMIT"
        } > "$STATUS_FILE"
    else
        echo "FAIL rc=$rc" > "$STATUS_FILE"
    fi
    [ "$(id -u)" -eq 0 ] && chown "$TARGET_USER" "$STATUS_FILE" 2>/dev/null || true
    exit "$rc"
}
trap finish EXIT
trap 'exit 130' HUP INT TERM

find_first()
{
    for p in "$@"; do
        [ -n "$p" ] && [ -f "$p" ] && { printf '%s' "$p"; return 0; }
    done
    return 1
}

FIRMWARE=$(find_first     "${AS2K_FIRMWARE:-}"     "$SCRIPT_DIR/AS2000_v3.1.4.bin"     "$SCRIPT_DIR/alphasmart2000.bin" || true)

DICTROM=$(find_first     "${AS2K_DICTROM:-}"     "$SCRIPT_DIR/dictrom.bin"     "$SCRIPT_DIR/dictrom__v1.stm_m27c1001-1501.plcc32.bin" || true)

[ -n "$FIRMWARE" ] ||
    die "Falta la ROM. Coloque AS2000_v3.1.4.bin junto al SH o defina AS2K_FIRMWARE"
[ -n "$DICTROM" ] ||
    die "Falta DictROM. Coloque dictrom.bin junto al SH o defina AS2K_DICTROM"

say "AS2K Emulator — instalación autónoma Surface RT"
echo "usuario=$TARGET_USER"
echo "home=$TARGET_HOME"
echo "arquitectura=$(uname -m)"
echo "AS2K=$AS2K_COMMIT"
echo "MAME=$MAME_COMMIT"

export GIT_TERMINAL_PROMPT=0

say "Actualizando índices e instalando todas las dependencias"
priv apk update
priv apk add --no-progress     git ca-certificates bash build-base pkgconf linux-headers     python3 py3-gobject3 gtk+3.0     ffmpeg cups cups-filters     sdl2-dev sdl2_ttf-dev     fontconfig-dev pulseaudio-dev alsa-lib-dev     libx11-dev libxinerama-dev libxi-dev libxrandr-dev     libxrender-dev libxext-dev mesa-dev expat-dev zlib-dev libarchive-dev     xdg-user-dirs desktop-file-utils

command -v git >/dev/null 2>&1 || die "git no quedó instalado"
command -v make >/dev/null 2>&1 || die "make no quedó instalado"
command -v g++ >/dev/null 2>&1 || die "g++ no quedó instalado"
command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg no quedó instalado"
command -v cupsfilter >/dev/null 2>&1 || die "cupsfilter no quedó instalado"
python3 -c 'import gi; gi.require_version("Gtk","3.0"); from gi.repository import Gtk' ||
    die "GTK3/PyGObject no quedó disponible"

checkout_exact()
{
    url=$1
    commit=$2
    dest=$3

    if [ -d "$dest/.git" ]; then
        dirty=$(git -c safe.directory="$dest" -C "$dest" status --porcelain)
        [ -z "$dirty" ] || die "$dest contiene cambios locales; no se modificará"
        git -c safe.directory="$dest" -C "$dest" fetch --depth 1 origin "$commit"
        git -c safe.directory="$dest" -C "$dest" checkout --detach -q FETCH_HEAD
    else
        mkdir -p "$dest"
        git -C "$dest" init -q
        git -C "$dest" remote add origin "$url"
        git -C "$dest" fetch --depth 1 origin "$commit"
        git -C "$dest" checkout --detach -q FETCH_HEAD
    fi

    actual=$(git -c safe.directory="$dest" -C "$dest" rev-parse HEAD)
    [ "$actual" = "$commit" ] || die "Revisión inesperada en $dest: $actual"
}

say "Descargando revisiones congeladas"
mkdir -p "$BUILD_ROOT"
checkout_exact "$AS2K_REPO" "$AS2K_COMMIT" "$AS2K_SRC"
checkout_exact "$MAME_REPO" "$MAME_COMMIT" "$MAME_SRC"

say "Validación estática"
sh "$AS2K_SRC/scripts/validate-stable-static.sh"

say "Compilación local reducida ARM — JOBS=$JOBS"
sh "$AS2K_SRC/scripts/build-stable-core.sh" "$MAME_SRC" "$JOBS"

say "Instalando core, frontend GTK y launcher"
priv sh "$AS2K_SRC/scripts/install-stable.sh" "$AS2K_SRC/out/as2k-bin" "$PREFIX"

say "Instalando ROM y DictROM privadas para $TARGET_USER"
mkdir -p "$CONFIG_DIR"
cp "$FIRMWARE" "$CONFIG_DIR/firmware.bin"
cp "$DICTROM" "$CONFIG_DIR/dictrom.bin"
chmod 600 "$CONFIG_DIR/firmware.bin" "$CONFIG_DIR/dictrom.bin"

say "Creando acceso directo"
DESKTOP_DIR=""
USER_DIRS="$TARGET_HOME/.config/user-dirs.dirs"
if [ -f "$USER_DIRS" ]; then
    DESKTOP_DIR=$(awk -F= -v home="$TARGET_HOME" '
        /^XDG_DESKTOP_DIR=/ {
            gsub(/"/, "", $2)
            gsub(/\$HOME/, home, $2)
            print $2
            exit
        }' "$USER_DIRS")
fi
if [ -z "$DESKTOP_DIR" ]; then
    if [ -d "$TARGET_HOME/Escritorio" ]; then
        DESKTOP_DIR="$TARGET_HOME/Escritorio"
    else
        DESKTOP_DIR="$TARGET_HOME/Desktop"
    fi
fi
mkdir -p "$DESKTOP_DIR"
cp "$PREFIX/share/applications/as2k.desktop" "$DESKTOP_DIR/AS2K Emulator.desktop"
chmod +x "$DESKTOP_DIR/AS2K Emulator.desktop"
if [ "$(id -u)" -eq 0 ]; then
    chown "$TARGET_USER" "$DESKTOP_DIR" "$DESKTOP_DIR/AS2K Emulator.desktop" 2>/dev/null || true
fi

say "Comprobaciones finales estáticas/build"
"$PREFIX/libexec/as2k/as2k-bin" -validate
python3 -c "compile(open('$PREFIX/libexec/as2k/frontend/as2k_ui.py', encoding='utf-8').read(), '$PREFIX/libexec/as2k/frontend/as2k_ui.py', 'exec')"
desktop-file-validate "$PREFIX/share/applications/as2k.desktop"
test -x "$PREFIX/bin/as2k"
test -f "$PREFIX/libexec/as2k/frontend/as2k_pcl_to_pdf.py"
test -f /usr/share/ppd/cupsfilters/Generic-PDF_Printer-PDF.ppd
ffmpeg -hide_banner -encoders 2>/dev/null | grep -q 'libx264' ||
    die "FFmpeg está instalado pero no ofrece el encoder libx264 requerido"

printf '%s\n' "$AS2K_COMMIT" > "$CONFIG_DIR/installed-commit.txt"

say "INSTALACIÓN AS2K SURFACE: PASS"
echo "Lanzador: $PREFIX/bin/as2k"
echo "Menú: AS2K Emulator"
echo "Escritorio: $DESKTOP_DIR/AS2K Emulator.desktop"
echo "Estado: $STATUS_FILE"
echo "Las pruebas funcionales quedan para aceptación humana."
