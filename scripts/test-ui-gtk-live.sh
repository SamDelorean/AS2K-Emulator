#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUT="$ROOT/out/ui-gtk-live"
rm -rf "$OUT"
mkdir -p "$OUT/runtime"
chmod 700 "$OUT/runtime"
REPORT="$OUT/report.txt"
LOG="$OUT/test.log"
: > "$REPORT"
: > "$LOG"

say() { printf '%s\n' "$*" | tee -a "$REPORT"; }
fail() { say "AS2K GTK live acceptance: FAIL — $*"; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "python3 missing"
python3 -c 'import gi; gi.require_version("Gtk","3.0"); from gi.repository import Gtk' >/dev/null 2>&1 || fail "GTK3/PyGObject missing"
command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg missing"
command -v cupsfilter >/dev/null 2>&1 || fail "cupsfilter missing"

cat > "$OUT/harness.py" <<'PY'
from __future__ import annotations
import importlib.util
import os
import pathlib
import shutil
import subprocess
import sys
import time

root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
frontend = root / 'frontend' / 'as2k_ui.py'
spec = importlib.util.spec_from_file_location('as2k_ui_live_test', frontend)
if spec is None or spec.loader is None:
    raise RuntimeError('cannot load frontend/as2k_ui.py')
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)

from gi.repository import Gio, GLib, Gtk

def pump(rounds=8):
    for _ in range(rounds):
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)
        time.sleep(0.01)

app = Gtk.Application(
    application_id='com.customretrostuff.as2k.liveacceptance',
    flags=Gio.ApplicationFlags.NON_UNIQUE,
)
assert app.register(None), 'GTK application registration failed'
window = ui.AS2KWindow(app)
window.show_all()
pump()

# Prove the real native Save-As dialog can open and close without user intervention.
def cancel_native_chooser():
    for candidate in Gtk.Window.list_toplevels():
        if isinstance(candidate, Gtk.FileChooserDialog):
            candidate.response(Gtk.ResponseType.CANCEL)
            return False
    return True
GLib.timeout_add(50, cancel_native_chooser)
assert window._save_dialog('Prueba de diálogo Guardar como', 'dialog-test.txt') is None
pump()

destinations = {
    'alphasmart-send.txt': out / 'send-live.txt',
    'alphasmart-print.pdf': out / 'print-live.pdf',
    'as2k-screen.png': out / 'lcd-live.png',
    'as2k-lcd.mp4': out / 'lcd-live.mp4',
}
window._save_dialog = lambda _title, default: destinations[default]

# Main GTK window/menu/header.
assert window.get_visible(), 'main GTK window not visible'
assert 'AS2K Emulator' in window.header.get_text()
assert window.pc_item.get_label() == 'PC conectado'
assert window.printer_item.get_label() == 'Impresora conectada'
assert window.ir_item.get_label() == 'Infrarrojo activo'

# Live 240x36 LCD bridge file -> GTK pixbuf.
frame = bytearray(ui.LCD_WIDTH * ui.LCD_HEIGHT)
for y in range(ui.LCD_HEIGHT):
    for x in range(ui.LCD_WIDTH):
        frame[y * ui.LCD_WIDTH + x] = 1 if ((x // 6 + y // 6) & 1) else 0
window.frame_file.write_bytes(frame)
assert window._poll_frame_file()
pump()
rgb = window._rgb_bytes()
assert len(rgb) == ui.LCD_WIDTH * ui.LCD_HEIGHT * 3
assert len(set(rgb[:1200])) > 1, 'LCD framebuffer did not reach GTK pixbuf'

# PC/printer machine state and exclusivity.
window.pc_item.set_active(True)
pump()
assert window.pc_connected and 'PC: ON' in window.header.get_text()
window.printer_item.set_active(True)
pump()
assert window.printer_connected and not window.pc_connected
assert 'PRN: ON' in window.header.get_text() and 'PC: OFF' in window.header.get_text()
window.printer_item.set_active(False)
pump()

# Completed Send event -> frontend Save-As -> TXT.
send_pending = out / '.pending-send.txt'
send_payload = b'AS2K GTK SEND LIVE TEST\r\n'
send_pending.write_bytes(send_payload)
with window.event_file.open('a', encoding='utf-8') as stream:
    stream.write(f'SEND_READY\t{send_pending}\n')
assert window._poll_events()
pump()
assert destinations['alphasmart-send.txt'].read_bytes() == send_payload
assert not send_pending.exists()

# Completed wired Print event -> actual frontend CUPS conversion -> PDF.
pcl_pending = out / '.pending-print.pcl'
pcl_pending.write_bytes(b'\x1bE\x1b&k3GAS2K GTK PRINT LIVE TEST\r\x1b&l0H\x1bE')
with window.event_file.open('a', encoding='utf-8') as stream:
    stream.write(f'PRINT_READY\t{pcl_pending}\n')
assert window._poll_events()
pump()
pdf = destinations['alphasmart-print.pdf']
assert pdf.is_file() and pdf.read_bytes().startswith(b'%PDF-')
assert not pcl_pending.exists()

# IR event path: rolling hex + completion, visualization only.
window.ir_item.set_active(True)
pump()
with window.event_file.open('a', encoding='utf-8') as stream:
    stream.write('IR_BYTES\tSEND\tC0 02 78 11 53 01 00 41 53 32 4B C1\n')
    stream.write('IR_DONE\n')
assert window._poll_events()
pump()
assert window.ir_total == 12
assert 'Transmission complete' in window.ir_label.get_text()
assert '12 bytes' in window.ir_label.get_text()
assert 'IR: ON' in window.header.get_text()
assert not list(out.glob('ir-*')) and not list(out.glob('ir_*'))

# Screenshot path.
window._save_screenshot()
pump()
png = destinations['as2k-screen.png']
assert png.is_file() and png.stat().st_size > 100

# MP4/H.264 no-audio path.
window._start_recording()
assert window.recording
for _ in range(30):
    assert window._write_video_frame()
    time.sleep(0.01)
window._stop_recording()
pump()
mp4 = destinations['as2k-lcd.mp4']
assert mp4.is_file() and mp4.stat().st_size > 1000
ffprobe = shutil.which('ffprobe')
if ffprobe:
    probe = subprocess.run(
        [ffprobe, '-v', 'error', '-show_entries', 'stream=codec_type',
         '-of', 'default=nw=1:nk=1', str(mp4)],
        check=True, capture_output=True, text=True,
    ).stdout.split()
    assert 'video' in probe and 'audio' not in probe

# Help -> keyboard shortcuts opens an actual GTK toplevel.
window._show_shortcuts()
pump()
help_windows = [
    item for item in Gtk.Window.list_toplevels()
    if 'Atajos de teclado' in (item.get_title() or '')
]
assert help_windows, 'keyboard shortcuts window did not open'
for item in help_windows:
    item.destroy()

# Scale modes used by Ver menu.
for scale in (1.0, 1.5, 2.0):
    window._set_scale(scale)
    pump(2)
    assert window.ui_scale == scale

window.destroy()
pump()
for name in (
    'WINDOW', 'NATIVE SAVE-AS DIALOG', 'LCD MIRROR', 'PC/PRINTER STATE',
    'SEND SAVE-AS', 'PRINT CUPS PDF', 'IR HEX/DONE', 'SCREENSHOT PNG',
    'MP4 NO-AUDIO', 'HELP SHORTCUTS', 'SCALE 100/150/200',
):
    print(f'AS2K GTK {name}: PASS')
PY

run_harness()
{
    XDG_RUNTIME_DIR="$OUT/runtime" \
    AS2K_UI_CONTROL_FILE="$OUT/runtime/control.queue" \
    AS2K_UI_EVENT_FILE="$OUT/runtime/events.queue" \
    AS2K_UI_FRAME_FILE="$OUT/runtime/lcd.bin" \
    python3 "$OUT/harness.py" "$ROOT" "$OUT" >"$LOG" 2>&1
}

if printenv DISPLAY >/dev/null 2>&1 && [ -n "$(printenv DISPLAY)" ]; then
    say "Display backend: existing DISPLAY=$(printenv DISPLAY)"
    run_harness || { cat "$LOG" >>"$REPORT"; fail "graphical test failed"; }
elif [ -S /tmp/.X11-unix/X0 ]; then
    say "Display backend: detected local X11 :0"
    DISPLAY=:0; export DISPLAY
    run_harness || { cat "$LOG" >>"$REPORT"; fail "graphical test failed"; }
elif command -v xvfb-run >/dev/null 2>&1; then
    say "Display backend: xvfb-run"
    XDG_RUNTIME_DIR="$OUT/runtime" \
    AS2K_UI_CONTROL_FILE="$OUT/runtime/control.queue" \
    AS2K_UI_EVENT_FILE="$OUT/runtime/events.queue" \
    AS2K_UI_FRAME_FILE="$OUT/runtime/lcd.bin" \
    xvfb-run -a -s '-screen 0 1280x800x24' \
        python3 "$OUT/harness.py" "$ROOT" "$OUT" >"$LOG" 2>&1 || {
            cat "$LOG" >>"$REPORT"
            fail "graphical xvfb test failed"
        }
else
    fail "no graphical display and xvfb-run unavailable"
fi

cat "$LOG" >>"$REPORT"
for artifact in send-live.txt print-live.pdf lcd-live.png lcd-live.mp4; do
    [ -s "$OUT/$artifact" ] || fail "missing artifact: $artifact"
done

if command -v file >/dev/null 2>&1; then
    file "$OUT"/send-live.txt "$OUT"/print-live.pdf "$OUT"/lcd-live.png "$OUT"/lcd-live.mp4 >>"$REPORT" 2>&1 || true
fi

say "AS2K GTK live acceptance: PASS"
say "Artifacts: $OUT"
