#!/usr/bin/env python3
"""AS2K Stable: gestor GTK para ROM, DictROM, bootstrap y menús.
Utiliza el frontend original y el núcleo reducido ya compilado, sin modificarlos.
"""
import importlib.util
import json
import os
import time
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gio
os.environ["AS2K_WORKBENCH"] = "1"  # local personal installation only

ROOT = Path("/usr/local/libexec/as2k")
UI_PY = ROOT / "frontend/as2k_ui.py"
CORE = ROOT / "as2k-bin"
spec = importlib.util.spec_from_file_location("as2k_original_frontend", str(UI_PY))
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "as2k"
DATA = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "as2k"
STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "as2k"
RUNTIME = (Path(os.environ["XDG_RUNTIME_DIR"]) / "as2k") if os.environ.get("XDG_RUNTIME_DIR") else Path(tempfile.gettempdir()) / ("as2k-" + str(os.getuid()))
SETTINGS = CONFIG / "session.json"
CFG = CONFIG / "cfg" / "asma2k.cfg"
VALID_SIZES = {"firmware": (0x8000, 0x81e5), "dictrom": (0x20000,)}
NVRAM_FILE = DATA / "nvram" / "asma2k" / "nvram"
NVRAM_BYTES = 0x20000
EXIT_REQUEST = RUNTIME / "as2k-exit.request"
EXIT_SCRIPT = RUNTIME / "as2k-exit.lua"
# MAME already uses this Lua API in its runtime keyboard tests. Requesting
# manager.machine:exit() returns through its normal NVRAM save path.
EXIT_LUA = """
local request = assert(os.getenv("AS2K_EXIT_REQUEST"))
emu.register_frame_done(function()
    local file = io.open(request, "rb")
    if file then
        file:close()
        manager.machine:exit()
    end
end, "as2k_graceful_exit")
"""


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".as2k-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            out.write(content)
        os.chmod(name, 0o600)
        os.replace(name, str(path))
    finally:
        if os.path.exists(name):
            os.unlink(name)

def valid_image(path, role):
    if not path:
        return False
    try:
        p = Path(path)
        return p.is_file() and p.stat().st_size in VALID_SIZES[role]
    except (OSError, ValueError):
        return False

class Session:
    def __init__(self):
        self.settings = {"firmware": "", "dictrom": "", "boot_mode": "normal", "bootstrap_rom": "", "bootstrap_enabled": "0", "display_mode": "integrated", "payload_name": "STOCK", "payload_file": ""}
        try:
            existing = json.loads(SETTINGS.read_text(encoding="utf-8"))
            if isinstance(existing, dict):
                for key in self.settings:
                    if isinstance(existing.get(key), str):
                        self.settings[key] = existing[key]
        except (OSError, ValueError):
            pass
        for role, env in (("firmware", "AS2K_FIRMWARE"), ("dictrom", "AS2K_DICTROM")):
            if os.environ.get(env):
                self.settings[role] = os.environ[env]
            elif not self.settings[role]:
                candidate = CONFIG / (role + ".bin")
                if candidate.is_file():
                    self.settings[role] = str(candidate)
        if self.settings["boot_mode"] not in ("normal", "dictrom"):
            self.settings["boot_mode"] = "normal"
        self.core = None
        self.log = None
        for folder in (CONFIG / "cfg", DATA / "nvram", DATA / "output", STATE / "states", RUNTIME):
            folder.mkdir(parents=True, exist_ok=True)
        os.chmod(RUNTIME, 0o700)
        os.environ["AS2K_UI_CONTROL_FILE"] = str(RUNTIME / "control.queue")
        os.environ["AS2K_UI_EVENT_FILE"] = str(RUNTIME / "events.queue")
        os.environ["AS2K_UI_FRAME_FILE"] = str(RUNTIME / "lcd.bin")

    def save(self):
        atomic_write(SETTINGS, json.dumps(self.settings, ensure_ascii=False, indent=2) + "\n")

    def ready(self):
        return (valid_image(self.settings["firmware"], "firmware") and
                valid_image(self.settings["dictrom"], "dictrom") and
                (self.settings["bootstrap_enabled"] != "1" or
                 valid_image(self.settings["bootstrap_rom"], "firmware")))

    def set_image(self, role, path):
        if not valid_image(path, role):
            raise ValueError("%s: tamaño incorrecto. Permitidos: %s bytes" % (role, VALID_SIZES[role]))
        self.settings[role] = str(Path(path).resolve())
        self.save()

    def update_boot_cfg(self):
        # MAME 0.289: campo CONFIG con puerto :BOOT_MODE, máscara 1.
        # Preservar otros ajustes del usuario y realizar una copia de recuperación.
        if CFG.exists():
            root = ET.parse(CFG).getroot()
            if root.tag != "mameconfig" or root.get("version") != "10":
                raise ValueError("La configuración actual de MAME no tiene formato versión 10; no se sobrescribe.")
        else:
            root = ET.Element("mameconfig", {"version": "10"})
        system = next((x for x in root.findall("system") if x.get("name") == "asma2k"), None)
        if system is None:
            system = ET.SubElement(root, "system", {"name": "asma2k"})
        input_node = system.find("input")
        if input_node is None:
            input_node = ET.SubElement(system, "input")
        old = [p for p in input_node.findall("port") if p.get("tag") in (":BOOT_MODE", "BOOT_MODE") and p.get("type") == "CONFIG"]
        entry = old[0] if old else ET.SubElement(input_node, "port")
        entry.attrib.update({"tag": ":BOOT_MODE", "type": "CONFIG", "mask": "1", "defvalue": "0",
                             "value": "1" if self.settings["boot_mode"] == "dictrom" else "0"})
        for extra in old[1:]:
            input_node.remove(extra)
        if CFG.exists():
            backup = CFG.with_suffix(".cfg.as2k-backup")
            if not backup.exists():
                backup.write_bytes(CFG.read_bytes())
        atomic_write(CFG, ET.tostring(root, encoding="unicode", xml_declaration=True) + "\n")

    def stop(self):
        if self.core is not None:
            if self.core.poll() is None:
                # Let MAME leave its run loop and execute nvram_save().
                # Do not send SIGTERM/SIGKILL: they bypass the save.
                EXIT_REQUEST.write_text("EXIT\n", encoding="ascii")
                try:
                    code = self.core.wait(timeout=12)
                except subprocess.TimeoutExpired as exc:
                    raise RuntimeError(
                        "No se confirmó el cierre normal de MAME. "
                        "El núcleo permanece activo para proteger la RAM."
                    ) from exc
            else:
                code = self.core.returncode
            if code != 0:
                raise RuntimeError(
                    "MAME terminó con error (%s); la RAM no se considera guardada." % code
                )
            if not NVRAM_FILE.is_file() or NVRAM_FILE.stat().st_size != NVRAM_BYTES:
                raise RuntimeError(
                    "MAME terminó, pero no generó una NVRAM válida de 131072 bytes."
                )
            self.core = None
        if self.log:
            self.log.close()
            self.log = None

    def start(self, window=None):
        if not self.ready():
            return False
        # MAME persists its configuration while exiting. Stop first, then
        # apply bootstrap selection to avoid overwriting the new mode.
        self.stop()
        self.update_boot_cfg()
        if NVRAM_FILE.exists() and (
            not NVRAM_FILE.is_file() or NVRAM_FILE.stat().st_size != NVRAM_BYTES
        ):
            raise ValueError("La NVRAM existente tiene un tamaño incorrecto; no se sobrescribe.")
        EXIT_REQUEST.unlink(missing_ok=True)
        atomic_write(EXIT_SCRIPT, EXIT_LUA)
        for name in ("control.queue", "events.queue"):
            (RUNTIME / name).write_text("", encoding="utf-8")
        (RUNTIME / "lcd.bin").unlink(missing_ok=True)
        if window is not None:
            window.event_offset = 0
            window.frame_mtime_ns = -1
            window._clear_lcd()
            window.lcd_area.queue_draw()
        fw = Path(self.settings["bootstrap_rom"] if self.settings["bootstrap_enabled"] == "1"
                  else self.settings["firmware"])
        self.log = (STATE / "core.log").open("w", encoding="utf-8")
        cmd = [str(CORE), "asma2k",
               "-rom1", str(fw), "-rom2", self.settings["dictrom"], "-rompath", str(fw.parent),
               "-cfg_directory", str(CONFIG / "cfg"), "-nvram_directory", str(DATA / "nvram"),
               "-snapshot_directory", str(DATA / "output"), "-state_directory", str(STATE / "states"),
               "-sound", "none", "-autoboot_script", str(EXIT_SCRIPT)]
        display = os.environ.get("AS2K_DISPLAY_MODE", self.settings["display_mode"])
        # Keep the SDL driver choice local to MAME, not the GTK process.
        # On Armbian, -video none alone still leaves an X11 window behind.
        core_env = os.environ.copy()
        core_env["AS2K_EXIT_REQUEST"] = str(EXIT_REQUEST)
        if display == "sdl":
            core_env["SDL_VIDEODRIVER"] = "x11"
            cmd += ["-window", "-nomaximize", "-video", "soft"]
        else:
            core_env["SDL_VIDEODRIVER"] = "dummy"
            cmd += ["-video", "none"]
        # An overriding script would disable safe shutdown and NVRAM saving.
        if any(arg.lower().startswith("-autoboot_script") for arg in sys.argv[1:]):
            raise ValueError("No se admite sobrescribir el script de cierre seguro de AS2K.")
        cmd.extend(sys.argv[1:])
        try:
            self.core = subprocess.Popen(cmd, stdout=self.log, stderr=subprocess.STDOUT,
                                         env=core_env)
        except OSError:
            self.stop()
            raise
        return True

    def open_folder(self, name):
        folder = {"ram": DATA / "nvram", "states": STATE / "states", "output": DATA / "output"}[name]
        Gio.AppInfo.launch_default_for_uri(folder.as_uri(), None)

session = Session()

def error_dialog(parent, text):
    d = Gtk.MessageDialog(transient_for=parent, modal=True, message_type=Gtk.MessageType.ERROR,
                          buttons=Gtk.ButtonsType.OK, text="AS2K Stable — configuración")
    d.format_secondary_text(str(text))
    d.run()
    d.destroy()

def configure_dialog(parent=None):
    d = Gtk.Dialog(title="AS2K — ROM, DictROM y bootstrap", transient_for=parent, modal=True)
    d.add_button("Cancelar", Gtk.ResponseType.CANCEL)
    d.add_button("Aplicar y arrancar", Gtk.ResponseType.OK)
    d.set_default_size(590, -1)
    box = d.get_content_area()
    box.set_spacing(9)
    box.set_border_width(14)
    txt = Gtk.Label(label="Selecciona las ROM originales. No se copiarán ni modificarán.")
    txt.set_xalign(0)
    box.pack_start(txt, False, False, 0)
    choices = {}
    for role, caption in (("firmware", "ROM AlphaSmart 2000 (32 KiB / ZPSD)"),
                          ("dictrom", "DictROM AlphaSmart 2000 (128 KiB)")):
        label = Gtk.Label(label=caption)
        label.set_xalign(0)
        box.pack_start(label, False, False, 0)
        chooser = Gtk.FileChooserButton.new("Seleccionar " + caption, Gtk.FileChooserAction.OPEN)
        current = session.settings[role]
        if current and Path(current).is_file():
            chooser.set_filename(current)
        box.pack_start(chooser, False, False, 0)
        choices[role] = chooser
    label = Gtk.Label(label="Modo de arranque")
    label.set_xalign(0)
    box.pack_start(label, False, False, 0)
    mode = Gtk.ComboBoxText()
    mode.append("normal", "Arranque normal (firmware stock)")
    mode.append("dictrom", "Arranque directo desde DictROM (sin ROM bootstrap opcional)")
    mode.set_active_id(session.settings["boot_mode"])
    box.pack_start(mode, False, False, 0)
    note = Gtk.Label(label="ROM bootstrap: Archivo → Abrir ROM bootstrap…; payload independiente: Archivo → Payload.")
    note.set_xalign(0)
    note.set_line_wrap(True)
    box.pack_start(note, False, False, 0)
    d.show_all()
    accepted = False
    while d.run() == Gtk.ResponseType.OK:
        try:
            paths = {k: chooser.get_filename() for k, chooser in choices.items()}
            for role, path in paths.items():
                if not valid_image(path, role):
                    raise ValueError("%s: selecciona un archivo compatible (%s bytes)." % (role, VALID_SIZES[role]))
            session.settings.update({role: str(Path(path).resolve()) for role, path in paths.items()})
            session.settings["boot_mode"] = mode.get_active_id() or "normal"
            if session.settings["boot_mode"] == "dictrom":
                session.settings["bootstrap_enabled"] = "0"
            session.save()
            accepted = True
            break
        except (OSError, ValueError) as exc:
            error_dialog(d, exc)
    d.destroy()
    return accepted

class ManagedWindow(ui.AS2KWindow):
    def _on_delete_event(self, *args):
        if super()._on_delete_event(*args):
            return True
        try:
            session.stop()
        except (OSError, RuntimeError) as exc:
            error_dialog(self, "No se cerró AS2K: " + str(exc))
            return True
        return False

    # Byte-wide, C-optimized LCD expansion; no nested per-pixel Python loops.
    def _poll_frame_file(self):
        if self.display_mode == "sdl":
            return False
        tick = time.monotonic()
        if tick - getattr(self, "_frame_tick", 0.0) < 0.040:
            return True
        self._frame_tick = tick
        try:
            st = self.frame_file.stat()
            if st.st_size != ui.LCD_WIDTH * ui.LCD_HEIGHT or st.st_mtime_ns == self.frame_mtime_ns:
                return True
            raw = self.frame_file.read_bytes()
        except OSError:
            return True
        if len(raw) != ui.LCD_WIDTH * ui.LCD_HEIGHT:
            return True
        self.frame_mtime_ns = st.st_mtime_ns
        if raw == getattr(self, "_frame_cache", None):
            return True
        rgb = raw.replace(b"\x00", bytes(ui.LCD_BG)).replace(b"\x01", bytes(ui.LCD_FG))
        if len(rgb) != len(raw)*3:
            return True
        self._frame_cache = raw
        self.lcd_pixbuf = ui.GdkPixbuf.Pixbuf.new_from_bytes(
            GLib.Bytes.new(rgb), ui.GdkPixbuf.Colorspace.RGB, False,
            8, ui.LCD_WIDTH, ui.LCD_HEIGHT, ui.LCD_WIDTH*3)
        self.lcd_area.queue_draw()
        return True

    def _build_menu_bar(self):
        bar = super()._build_menu_bar()
        self._building_modes = True
        file_root = next((m for m in bar.get_children() if m.get_label() == "Archivo"), None)
        if file_root:
            menu = file_root.get_submenu()
            self._menu_item(menu, "Abrir ROM bootstrap…", self._choose_bootstrap_rom)
            self.bootstrap_toggle = self._check_item(
                menu, "Usar ROM bootstrap al arrancar", self._toggle_bootstrap_rom)
            self.bootstrap_toggle.set_active(session.settings["bootstrap_enabled"] == "1")
        machine = next((m for m in bar.get_children() if m.get_label() == "Máquina"), None)
        if machine:
            target = machine.get_submenu()
            target.append(Gtk.SeparatorMenuItem())
            entry = Gtk.MenuItem(label="Bootstrap / inicio")
            submenu = Gtk.Menu()
            entry.set_submenu(submenu)
            group = None
            for label, value in (("Arranque normal (stock)", "normal"),
                                 ("Arranque directo desde DictROM", "dictrom")):
                item = Gtk.RadioMenuItem.new_with_label(group, label)
                group = item.get_group()
                item.connect("toggled", self._change_boot, value)
                item.set_active(value == session.settings["boot_mode"])
                submenu.append(item)
            submenu.append(Gtk.SeparatorMenuItem())
            target.append(entry)
            self._menu_item(target, "Aplicar ROM/bootstrap y reiniciar núcleo", self._restart)
        config = next((m for m in bar.get_children() if m.get_label() == "Configuración"), None)
        if config:
            target = config.get_submenu()
            target.append(Gtk.SeparatorMenuItem())
            self._menu_item(target, "Configurar ROM, DictROM y arranque…", self._configure)
            self._menu_item(target, "Abrir carpeta RAM/NVRAM…", lambda *_: self._folder("ram"))
            self._menu_item(target, "Abrir carpeta de estados…", lambda *_: self._folder("states"))
            self._menu_item(target, "Abrir carpeta de impresión/Send…", lambda *_: self._folder("output"))
        view = next((m for m in bar.get_children() if m.get_label() == "Ver"), None)
        if view:
            viewmenu = view.get_submenu()
            viewmenu.append(Gtk.SeparatorMenuItem())
            group = None
            for caption, value in (("Ventana integrada", "integrated"),
                                   ("Dos ventanas (respaldo SDL)", "sdl")):
                radio = Gtk.RadioMenuItem.new_with_label(group, caption)
                group = radio.get_group()
                radio.connect("toggled", self._select_display_mode, value)
                radio.set_active(value == session.settings["display_mode"])
                viewmenu.append(radio)
        self._building_modes = False
        return bar

    def __init__(self, app):
        self._payload_init = True
        self.display_mode = os.environ.get("AS2K_DISPLAY_MODE", session.settings["display_mode"])
        self._frame_tick = 0.0
        self._frame_cache = None
        super().__init__(app)
        self._payload_init = False
        self.set_title("AS2K Emulator")
        if self.display_mode == "sdl":
            frame = self.lcd_area.get_parent()
            frame.set_no_show_all(True)
            frame.hide()
        else:
            # Preserve the Vontar's familiar initial 200% LCD viewport, but
            # select the corresponding GTK radio item so the view menu and
            # actual render scale cannot disagree.
            self._scale_menu_items[2.0].set_active(True)
            self.set_default_size(760, 420)
        selected = session.settings["payload_name"]
        if selected == "EXT" and Path(session.settings["payload_file"]).is_file():
            self.payload_name = "EXT"
            self.payload_path = Path(session.settings["payload_file"])
            self._send_control("PAYLOAD_FILE " + str(self.payload_path))
        else:
            if selected not in ("STOCK", "P0", "P1", "P1B", "P2"):
                selected = "STOCK"
            self.payload_name = selected
            self._send_control("PAYLOAD " + selected)
        self._update_header()
        self.status.set_text("Núcleo iniciado." if session.core else
                             "Faltan ROM/DictROM: Configuración → Configurar ROM, DictROM y arranque…")
        GLib.timeout_add_seconds(2, self._check_core)

    def _check_core(self):
        if session.core is not None and session.core.poll() is not None:
            try:
                session.stop()
                self.status.set_text("Núcleo finalizado; archivo RAM verificado.")
            except (OSError, RuntimeError) as exc:
                self.status.set_text("NVRAM no verificada: " + str(exc))
        return True

    def _change_boot(self, item, value):
        if self._building_modes or not item.get_active():
            return
        if session.settings["boot_mode"] != value:
            session.settings["boot_mode"] = value
            if value == "dictrom":
                session.settings["bootstrap_enabled"] = "0"
                self._building_modes = True
                self.bootstrap_toggle.set_active(False)
                self._building_modes = False
            session.save()
            self.status.set_text("Bootstrap seleccionado. Máquina → Aplicar ROM/bootstrap y reiniciar núcleo")

    def _choose_bootstrap_rom(self, *_args):
        path = self._choose_file("Abrir ROM bootstrap")
        if not path:
            return
        try:
            if not valid_image(path, "firmware"):
                raise ValueError("La ROM bootstrap debe ser compatible con la ranura ROM1 (32768 o 33253 bytes).")
            session.settings["bootstrap_rom"] = str(path.resolve())
            session.settings["bootstrap_enabled"] = "1"
            session.settings["boot_mode"] = "normal"
            session.save()
            self._building_modes = True
            try:
                self.bootstrap_toggle.set_active(True)
            finally:
                self._building_modes = False
            if session.ready():
                self._restart()
        except (OSError, ValueError) as exc:
            error_dialog(self, exc)

    def _toggle_bootstrap_rom(self, item):
        if self._building_modes:
            return
        enabled = item.get_active()
        if enabled and not valid_image(session.settings["bootstrap_rom"], "firmware"):
            item.set_active(False)
            self.status.set_text("Selecciona primero una ROM bootstrap compatible.")
            return
        session.settings["bootstrap_enabled"] = "1" if enabled else "0"
        if enabled:
            session.settings["boot_mode"] = "normal"
        session.save()
        if session.ready():
            self._restart()

    def _select_display_mode(self, item, value):
        if self._building_modes or not item.get_active():
            return
        if session.settings["display_mode"] != value:
            session.settings["display_mode"] = value
            session.save()
            self.status.set_text("Modo guardado. Cierra y abre AS2K para aplicar el cambio.")

    def _payload_selected(self, item, name):
        if not item.get_active() or getattr(self, "_payload_init", False):
            return
        session.settings["payload_name"] = name
        session.settings["payload_file"] = ""
        session.save()
        self.payload_name = name
        self.payload_path = None
        self._send_control("PAYLOAD " + name)
        self._update_header()

    def _choose_external_payload(self, *_args):
        path = self._choose_file("Abrir payload externo")
        if not path:
            return
        try:
            if not path.is_file() or path.stat().st_size == 0:
                raise ValueError("El archivo debe existir y no estar vacío.")
            value = str(path.resolve())
            session.settings["payload_name"] = "EXT"
            session.settings["payload_file"] = value
            session.save()
            self.payload_name = "EXT"
            self.payload_path = Path(value)
            self._send_control("PAYLOAD_FILE " + value)
            self._update_header()
        except (OSError, ValueError) as exc:
            error_dialog(self, exc)

    def _folder(self, name):
        try:
            session.open_folder(name)
        except Exception as exc:
            error_dialog(self, exc)

    def _configure(self, *_args):
        if configure_dialog(self):
            self._restart()

    def _choose_firmware(self, *_args):
        self._select_image("firmware", "Seleccionar ROM AlphaSmart 2000")

    def _choose_dictrom(self, *_args):
        self._select_image("dictrom", "Seleccionar DictROM")

    def _select_image(self, role, title):
        path = self._choose_file(title)
        if path:
            try:
                session.set_image(role, path)
                if role == "firmware":
                    session.settings["bootstrap_enabled"] = "0"
                    session.save()
                    self._building_modes = True
                    self.bootstrap_toggle.set_active(False)
                    self._building_modes = False
                if session.ready():
                    self._restart()
                else:
                    self.status.set_text("Imagen guardada. Selecciona también la otra ROM.")
            except Exception as exc:
                error_dialog(self, exc)

    def _reset_machine(self, *_args):
        self._restart()

    def _restart(self, *_args):
        if not session.ready():
            self.status.set_text("Selecciona ROM y DictROM válidas en Configuración.")
            return
        try:
            session.start(self)
            self._frame_cache = None
            self.frame_mtime_ns = -1
            self.status.set_text("Núcleo reiniciado; inicio: " + session.settings["boot_mode"] +
                                 ("; ROM bootstrap" if session.settings["bootstrap_enabled"] == "1" else ""))
        except Exception as exc:
            error_dialog(self, exc)

class ManagedApplication(ui.AS2KApplication):
    def do_activate(self):
        window = self.props.active_window
        if not window:
            window = ManagedWindow(self)
        window.show_all()
        window.present()

def main():
    try:
        if not UI_PY.is_file() or not CORE.is_file():
            raise RuntimeError("AS2K Stable incompleto: faltan frontend o núcleo.")
        if not session.ready():
            configure_dialog()
        if session.ready():
            session.start()
        return ManagedApplication().run(sys.argv[:1])
    finally:
        session.stop()

if __name__ == "__main__":
    raise SystemExit(main())
