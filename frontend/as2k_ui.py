#!/usr/bin/env python3
"""AS2K Emulator GTK3 front-end shell.

This module intentionally keeps hardware semantics in the emulator core.
It provides the stable application identity, menus, LCD presentation,
virtual special keys, capture helpers, and the workbench-only payload selector.
The core bridge is intentionally narrow: commands and events use small
append-only runtime queue files, and the LCD is mirrored from an 8-bit 240x36
frame file.  Paths are supplied through AS2K_UI_CONTROL_FILE,
AS2K_UI_EVENT_FILE and AS2K_UI_FRAME_FILE.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk  # noqa: E402

LCD_WIDTH = 240
LCD_HEIGHT = 36
LCD_BG = (138, 146, 148)
LCD_FG = (92, 83, 88)
VIDEO_FPS = 25
VIDEO_SCALE = 4
IR_VISIBLE_BYTES = 64


def xdg_runtime_dir() -> Path:
    value = os.environ.get("XDG_RUNTIME_DIR")
    if value:
        return Path(value) / "as2k"
    return Path(tempfile.gettempdir()) / f"as2k-{os.getuid()}"


class AS2KWindow(Gtk.ApplicationWindow):
    def __init__(self, app: Gtk.Application) -> None:
        super().__init__(application=app)
        self.set_title("AS2K Emulator")
        self.set_border_width(0)
        self.connect("delete-event", self._on_delete_event)

        self.pc_connected = False
        self.printer_connected = False
        self.ir_enabled = False
        self.recording = False
        self.workbench = os.environ.get("AS2K_WORKBENCH", "0") == "1"
        self.payload_name = "STOCK"
        self.payload_path: Optional[Path] = None
        self.firmware_path: Optional[Path] = None
        self.dictrom_path: Optional[Path] = None
        self.send_capture = bytearray()
        self.ir_tail = bytearray()
        self.ir_total = 0
        self.ir_mode = ""

        runtime = xdg_runtime_dir()
        runtime.mkdir(parents=True, exist_ok=True)
        self.control_file = Path(os.environ.get("AS2K_UI_CONTROL_FILE", runtime / "control.queue"))
        self.event_file = Path(os.environ.get("AS2K_UI_EVENT_FILE", runtime / "events.queue"))
        self.frame_file = Path(os.environ.get("AS2K_UI_FRAME_FILE", runtime / "lcd.bin"))
        self.frame_mtime_ns = -1
        self.event_offset = 0
        self.control_file.write_text("", encoding="utf-8")
        self.event_file.write_text("", encoding="utf-8")

        self.video_process: Optional[subprocess.Popen] = None
        self.video_tmp: Optional[Path] = None
        self.video_timer: int = 0

        self.lcd_pixbuf = GdkPixbuf.Pixbuf.new(
            GdkPixbuf.Colorspace.RGB, False, 8, LCD_WIDTH, LCD_HEIGHT
        )
        self._clear_lcd()

        self._build_ui()
        self._update_header()
        self._update_ir_line("IR: OFF")
        GLib.timeout_add(20, self._poll_frame_file)
        GLib.timeout_add(50, self._poll_events)

    def _build_ui(self) -> None:
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(root)

        self.header = Gtk.Label()
        self.header.set_xalign(0.0)
        self.header.set_margin_start(10)
        self.header.set_margin_end(10)
        self.header.set_margin_top(6)
        self.header.set_margin_bottom(6)
        root.pack_start(self.header, False, False, 0)

        root.pack_start(self._build_menu_bar(), False, False, 0)

        lcd_frame = Gtk.Frame()
        lcd_frame.set_shadow_type(Gtk.ShadowType.IN)
        lcd_frame.set_margin_start(12)
        lcd_frame.set_margin_end(12)
        lcd_frame.set_margin_top(12)
        lcd_frame.set_margin_bottom(8)
        self.lcd_area = Gtk.DrawingArea()
        self.lcd_area.connect("draw", self._draw_lcd)
        lcd_frame.add(self.lcd_area)
        root.pack_start(lcd_frame, True, True, 0)

        self.ir_label = Gtk.Label()
        self.ir_label.set_xalign(0.0)
        self.ir_label.set_selectable(True)
        self.ir_label.set_margin_start(12)
        self.ir_label.set_margin_end(12)
        self.ir_label.set_margin_bottom(6)
        root.pack_start(self.ir_label, False, False, 0)

        key_scroller = Gtk.ScrolledWindow()
        key_scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER)
        key_scroller.set_shadow_type(Gtk.ShadowType.NONE)
        key_scroller.set_margin_start(8)
        key_scroller.set_margin_end(8)
        key_scroller.set_margin_bottom(8)
        keys = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        key_scroller.add(keys)
        for label, command in self._virtual_keys():
            button = Gtk.Button(label=label)
            button.set_can_focus(False)
            button.connect("clicked", self._on_virtual_key, command)
            keys.pack_start(button, False, False, 0)
        root.pack_start(key_scroller, False, False, 0)

        self.status = Gtk.Label(label="Frontend ready; emulator bridge not yet connected")
        self.status.set_xalign(0.0)
        self.status.set_margin_start(10)
        self.status.set_margin_end(10)
        self.status.set_margin_bottom(6)
        root.pack_start(self.status, False, False, 0)

        self._set_scale(1.0)

    def _build_menu_bar(self) -> Gtk.MenuBar:
        bar = Gtk.MenuBar()

        file_menu = Gtk.Menu()
        file_root = Gtk.MenuItem(label="Archivo")
        file_root.set_submenu(file_menu)
        bar.append(file_root)
        self._menu_item(file_menu, "Abrir ROM…", self._choose_firmware)
        self._menu_item(file_menu, "Abrir DictROM…", self._choose_dictrom)
        file_menu.append(Gtk.SeparatorMenuItem())
        if self.workbench:
            file_menu.append(self._build_payload_menu())
            file_menu.append(Gtk.SeparatorMenuItem())
        self._menu_item(file_menu, "Captura de pantalla…", self._save_screenshot)
        self.record_start_item = self._menu_item(file_menu, "Iniciar grabación", self._start_recording)
        self.record_stop_item = self._menu_item(file_menu, "Detener y guardar…", self._stop_recording)
        self.record_stop_item.set_sensitive(False)
        file_menu.append(Gtk.SeparatorMenuItem())
        self._menu_item(file_menu, "Salir", lambda *_: self.close())

        machine_menu = Gtk.Menu()
        machine_root = Gtk.MenuItem(label="Máquina")
        machine_root.set_submenu(machine_menu)
        bar.append(machine_root)
        self._menu_item(machine_menu, "Reiniciar AlphaSmart", self._reset_machine)
        self._menu_item(machine_menu, "Encender / apagar", self._toggle_power)
        machine_menu.append(Gtk.SeparatorMenuItem())
        self.pc_item = self._check_item(machine_menu, "PC conectado", self._toggle_pc)
        self.printer_item = self._check_item(machine_menu, "Impresora conectada", self._toggle_printer)
        self.ir_item = self._check_item(machine_menu, "Infrarrojo activo", self._toggle_ir)

        view_menu = Gtk.Menu()
        view_root = Gtk.MenuItem(label="Ver")
        view_root.set_submenu(view_menu)
        bar.append(view_root)
        scale_group = None
        for label, scale in (("100 %", 1.0), ("150 %", 1.5), ("200 %", 2.0)):
            item = Gtk.RadioMenuItem.new_with_label(scale_group, label)
            scale_group = item.get_group()
            item.connect("toggled", self._on_scale_selected, scale)
            if scale == 1.0:
                item.set_active(True)
            view_menu.append(item)
        view_menu.append(Gtk.SeparatorMenuItem())
        full = Gtk.CheckMenuItem(label="Pantalla completa")
        full.connect("toggled", self._toggle_fullscreen)
        view_menu.append(full)

        config_menu = Gtk.Menu()
        config_root = Gtk.MenuItem(label="Configuración")
        config_root.set_submenu(config_menu)
        bar.append(config_root)
        self._menu_item(config_menu, "Mostrar rutas de trabajo", self._show_paths)

        help_menu = Gtk.Menu()
        help_root = Gtk.MenuItem(label="Ayuda")
        help_root.set_submenu(help_menu)
        bar.append(help_root)
        self._menu_item(help_menu, "Atajos de teclado…", self._show_shortcuts)
        help_menu.append(Gtk.SeparatorMenuItem())
        self._menu_item(help_menu, "Acerca de AS2K Emulator", self._show_about)

        return bar

    def _build_payload_menu(self) -> Gtk.MenuItem:
        root = Gtk.MenuItem(label="Payload")
        menu = Gtk.Menu()
        root.set_submenu(menu)
        group = None
        for label, name in (
            ("Ninguno / arranque normal", "STOCK"),
            ("Payload-0", "P0"),
            ("Payload-1", "P1"),
            ("Payload-1b", "P1B"),
            ("Payload-2", "P2"),
        ):
            item = Gtk.RadioMenuItem.new_with_label(group, label)
            group = item.get_group()
            item.connect("toggled", self._payload_selected, name)
            if name == "STOCK":
                item.set_active(True)
            menu.append(item)
        menu.append(Gtk.SeparatorMenuItem())
        self._menu_item(menu, "Abrir payload externo…", self._choose_external_payload)
        return root

    @staticmethod
    def _virtual_keys():
        return [
            ("Power", "KEY POWER"), ("Esc", "KEY ESC"),
            *[(f"F{i}", f"KEY F{i}") for i in range(1, 9)],
            ("Print", "KEY PRINT"), ("Spell", "KEY SPELL"),
            ("Find", "KEY FIND"), ("Clear", "KEY CLEAR"),
            ("Home", "KEY HOME"), ("End", "KEY END"),
            ("Enter", "KEY ENTER"), ("Send", "KEY SEND"),
        ]

    @staticmethod
    def _menu_item(menu: Gtk.Menu, label: str, callback):
        item = Gtk.MenuItem(label=label)
        item.connect("activate", callback)
        menu.append(item)
        return item

    @staticmethod
    def _check_item(menu: Gtk.Menu, label: str, callback):
        item = Gtk.CheckMenuItem(label=label)
        item.connect("toggled", callback)
        menu.append(item)
        return item

    def _clear_lcd(self) -> None:
        r, g, b = LCD_BG
        self.lcd_pixbuf.fill((r << 24) | (g << 16) | (b << 8) | 0xFF)

    def _draw_lcd(self, widget: Gtk.DrawingArea, cr) -> bool:
        alloc = widget.get_allocation()
        scale = min(alloc.width / LCD_WIDTH, alloc.height / LCD_HEIGHT)
        scale = max(scale, 1.0)
        width = LCD_WIDTH * scale
        height = LCD_HEIGHT * scale
        x = (alloc.width - width) / 2.0
        y = (alloc.height - height) / 2.0

        cr.save()
        cr.translate(x, y)
        cr.scale(scale, scale)
        Gdk.cairo_set_source_pixbuf(cr, self.lcd_pixbuf, 0, 0)
        cr.get_source().set_filter(0)
        cr.paint()
        cr.restore()
        return False

    def _set_scale(self, scale: float) -> None:
        self.ui_scale = scale
        self.lcd_area.set_size_request(int(LCD_WIDTH * scale), int(LCD_HEIGHT * scale))
        self.queue_resize()

    def _on_scale_selected(self, item: Gtk.RadioMenuItem, scale: float) -> None:
        if item.get_active():
            self._set_scale(scale)

    def _toggle_fullscreen(self, item: Gtk.CheckMenuItem) -> None:
        if item.get_active():
            self.fullscreen()
        else:
            self.unfullscreen()

    def _update_header(self) -> None:
        prefix = "AS2K Emulator"
        if self.workbench:
            prefix += f" [WORKBENCH] — {self.payload_name}"
        states = (
            f"PC: {'ON' if self.pc_connected else 'OFF'}",
            f"IR: {'TX' if self.ir_mode else ('ON' if self.ir_enabled else 'OFF')}",
            f"PRN: {'ON' if self.printer_connected else 'OFF'}",
        )
        rec = " | REC" if self.recording else ""
        self.header.set_text(prefix + " — " + " | ".join(states) + rec)

    def _update_ir_line(self, text: str) -> None:
        self.ir_label.set_text(text)

    def _send_control(self, command: str) -> bool:
        try:
            with self.control_file.open("a", encoding="utf-8") as stream:
                stream.write(command + "\n")
            self.status.set_text(command)
            return True
        except OSError as exc:
            self.status.set_text(f"No se pudo enviar al backend: {exc}")
            return False

    def _poll_events(self) -> bool:
        try:
            size = self.event_file.stat().st_size
            if size < self.event_offset:
                self.event_offset = 0
            if size == self.event_offset:
                return True
            with self.event_file.open("r", encoding="utf-8", errors="replace") as stream:
                stream.seek(self.event_offset)
                chunk = stream.read()
                self.event_offset = stream.tell()
        except OSError:
            return True

        for line in chunk.splitlines():
            self._handle_event(line)
        return True

    def _handle_event(self, line: str) -> None:
        if not line:
            return
        parts = line.split("\t")
        kind = parts[0]
        if kind == "STATUS" and len(parts) >= 2:
            self.status.set_text(parts[1])
            return
        if kind == "SEND_READY" and len(parts) >= 2:
            path = Path(parts[1])
            try:
                data = path.read_bytes()
                path.unlink(missing_ok=True)
            except OSError as exc:
                self._error("No se pudo leer la captura Send", str(exc))
                return
            if data:
                self.send_capture[:] = data
                self._save_send_capture()
            return
        if kind == "IR_BYTES" and len(parts) >= 3:
            try:
                data = bytes.fromhex(parts[2])
            except ValueError:
                return
            self.receive_ir_bytes(data, parts[1])
            return
        if kind == "IR_DONE":
            self.finish_ir_transfer()
            return

    def _poll_frame_file(self) -> bool:
        try:
            st = self.frame_file.stat()
            if st.st_mtime_ns == self.frame_mtime_ns or st.st_size != LCD_WIDTH * LCD_HEIGHT:
                return True
            raw = self.frame_file.read_bytes()
        except OSError:
            return True

        self.frame_mtime_ns = st.st_mtime_ns
        pixels = self.lcd_pixbuf.get_pixels()
        stride = self.lcd_pixbuf.get_rowstride()
        bg = LCD_BG
        fg = LCD_FG
        try:
            for y in range(LCD_HEIGHT):
                dst = y * stride
                src = y * LCD_WIDTH
                for x in range(LCD_WIDTH):
                    color = fg if raw[src + x] else bg
                    p = dst + 3 * x
                    pixels[p] = color[0]
                    pixels[p + 1] = color[1]
                    pixels[p + 2] = color[2]
        except TypeError:
            data = bytearray(stride * LCD_HEIGHT)
            for y in range(LCD_HEIGHT):
                dst = y * stride
                src = y * LCD_WIDTH
                for x in range(LCD_WIDTH):
                    color = fg if raw[src + x] else bg
                    p = dst + 3 * x
                    data[p:p + 3] = bytes(color)
            self.lcd_pixbuf = GdkPixbuf.Pixbuf.new_from_bytes(
                GLib.Bytes.new(bytes(data)), GdkPixbuf.Colorspace.RGB,
                False, 8, LCD_WIDTH, LCD_HEIGHT, stride
            )
        self.lcd_area.queue_draw()
        return True

    def receive_send_text(self, data: bytes) -> None:
        self.send_capture.extend(data)

    def receive_ir_bytes(self, data: bytes, mode: str = "TX") -> None:
        if not data:
            return
        self.ir_mode = mode.upper()
        self.ir_total += len(data)
        self.ir_tail.extend(data)
        if len(self.ir_tail) > IR_VISIBLE_BYTES:
            del self.ir_tail[:-IR_VISIBLE_BYTES]
        hex_tail = " ".join(f"{b:02X}" for b in self.ir_tail)
        self._update_ir_line(f"IR {self.ir_mode}: … {hex_tail} — {self.ir_total} bytes")
        self._update_header()

    def finish_ir_transfer(self) -> None:
        mode = self.ir_mode or "TX"
        self._update_ir_line(f"IR: Transmission complete — {mode} — {self.ir_total} bytes")
        self.ir_mode = ""
        self._update_header()

    def _on_virtual_key(self, _button: Gtk.Button, command: str) -> None:
        self._send_control(command)

    def _reset_machine(self, *_args) -> None:
        self._send_control("MACHINE RESET")

    def _toggle_power(self, *_args) -> None:
        self._send_control("MACHINE POWER")

    def _toggle_pc(self, item: Gtk.CheckMenuItem) -> None:
        self.pc_connected = item.get_active()
        self._send_control(f"PC {'ON' if self.pc_connected else 'OFF'}")
        self._update_header()
        # A completed capture is published asynchronously by the core as
        # SEND_READY after the physical-port decoder closes the PC session.

    def _toggle_printer(self, item: Gtk.CheckMenuItem) -> None:
        self.printer_connected = item.get_active()
        self._send_control(f"PRINTER {'ON' if self.printer_connected else 'OFF'}")
        self._update_header()

    def _toggle_ir(self, item: Gtk.CheckMenuItem) -> None:
        self.ir_enabled = item.get_active()
        self._send_control(f"IR {'ON' if self.ir_enabled else 'OFF'}")
        if self.ir_enabled:
            self._update_ir_line("IR: Ready")
        else:
            self.ir_mode = ""
            self.ir_total = 0
            self.ir_tail.clear()
            self._update_ir_line("IR: OFF")
        self._update_header()

    def _choose_file(self, title: str) -> Optional[Path]:
        dialog = Gtk.FileChooserDialog(
            title=title, transient_for=self, action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK,
        )
        result = None
        if dialog.run() == Gtk.ResponseType.OK:
            result = Path(dialog.get_filename())
        dialog.destroy()
        return result

    def _choose_firmware(self, *_args) -> None:
        path = self._choose_file("Seleccionar ROM de AlphaSmart 2000")
        if path:
            self.firmware_path = path
            self._send_control(f"FIRMWARE {path}")

    def _choose_dictrom(self, *_args) -> None:
        path = self._choose_file("Seleccionar DictROM")
        if path:
            self.dictrom_path = path
            self._send_control(f"DICTROM {path}")

    def _payload_selected(self, item: Gtk.RadioMenuItem, name: str) -> None:
        if not item.get_active():
            return
        self.payload_name = name
        self.payload_path = None
        self._send_control(f"PAYLOAD {name}")
        self._update_header()

    def _choose_external_payload(self, *_args) -> None:
        path = self._choose_file("Seleccionar payload externo")
        if path:
            self.payload_name = "EXT"
            self.payload_path = path
            self._send_control(f"PAYLOAD_FILE {path}")
            self._update_header()

    def _save_dialog(self, title: str, default_name: str) -> Optional[Path]:
        dialog = Gtk.FileChooserDialog(
            title=title, transient_for=self, action=Gtk.FileChooserAction.SAVE
        )
        dialog.set_do_overwrite_confirmation(True)
        dialog.set_current_name(default_name)
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_SAVE, Gtk.ResponseType.OK,
        )
        result = None
        if dialog.run() == Gtk.ResponseType.OK:
            result = Path(dialog.get_filename())
        dialog.destroy()
        return result

    def _save_screenshot(self, *_args) -> None:
        path = self._save_dialog("Guardar captura de pantalla", "as2k-screen.png")
        if not path:
            return
        if path.suffix.lower() != ".png":
            path = path.with_suffix(".png")
        try:
            self.lcd_pixbuf.savev(str(path), "png", [], [])
            self.status.set_text(f"Captura guardada: {path}")
        except GLib.Error as exc:
            self._error("No se pudo guardar la captura", str(exc))

    def _rgb_bytes(self) -> bytes:
        raw = bytes(self.lcd_pixbuf.get_pixels())
        stride = self.lcd_pixbuf.get_rowstride()
        row = LCD_WIDTH * 3
        if stride == row:
            return raw[:row * LCD_HEIGHT]
        return b"".join(raw[y * stride:y * stride + row] for y in range(LCD_HEIGHT))

    def _start_recording(self, *_args) -> None:
        if self.recording:
            return
        ffmpeg = shutil.which("ffmpeg")
        if not ffmpeg:
            self._error("FFmpeg no está disponible", "Instale FFmpeg para grabar MP4/H.264.")
            return

        fd, tmp_name = tempfile.mkstemp(prefix="as2k-record-", suffix=".mp4")
        os.close(fd)
        self.video_tmp = Path(tmp_name)
        command = [
            ffmpeg, "-loglevel", "error", "-y",
            "-f", "rawvideo", "-pixel_format", "rgb24",
            "-video_size", f"{LCD_WIDTH}x{LCD_HEIGHT}",
            "-framerate", str(VIDEO_FPS), "-i", "-",
            "-an", "-vf", f"scale={LCD_WIDTH * VIDEO_SCALE}:{LCD_HEIGHT * VIDEO_SCALE}:flags=neighbor",
            "-c:v", "libx264", "-pix_fmt", "yuv420p",
            str(self.video_tmp),
        ]
        try:
            self.video_process = subprocess.Popen(
                command, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE
            )
        except OSError as exc:
            self._error("No se pudo iniciar FFmpeg", str(exc))
            self.video_process = None
            self.video_tmp.unlink(missing_ok=True)
            self.video_tmp = None
            return

        self.recording = True
        self.record_start_item.set_sensitive(False)
        self.record_stop_item.set_sensitive(True)
        self.video_timer = GLib.timeout_add(int(1000 / VIDEO_FPS), self._write_video_frame)
        self._update_header()
        self.status.set_text("Grabación MP4 iniciada")

    def _write_video_frame(self) -> bool:
        if not self.recording or not self.video_process or not self.video_process.stdin:
            return False
        try:
            self.video_process.stdin.write(self._rgb_bytes())
            self.video_process.stdin.flush()
            return True
        except (BrokenPipeError, OSError):
            self.status.set_text("FFmpeg terminó inesperadamente")
            return False

    def _finalize_recording(self) -> bool:
        if not self.recording:
            return False
        if self.video_timer:
            GLib.source_remove(self.video_timer)
            self.video_timer = 0
        self.recording = False
        self.record_start_item.set_sensitive(True)
        self.record_stop_item.set_sensitive(False)
        self._update_header()

        proc = self.video_process
        self.video_process = None
        if proc and proc.stdin:
            try:
                proc.stdin.close()
            except OSError:
                pass
        if proc:
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.terminate()
                proc.wait(timeout=2)
            if proc.returncode:
                err = b""
                if proc.stderr:
                    err = proc.stderr.read()[-2000:]
                self._error("FFmpeg no pudo finalizar el video", err.decode("utf-8", "replace"))
                return False
        return True

    def _stop_recording(self, *_args) -> None:
        if not self.recording:
            return
        if not self._finalize_recording() or not self.video_tmp:
            return
        path = self._save_dialog("Guardar video", "as2k-lcd.mp4")
        if not path:
            self.video_tmp.unlink(missing_ok=True)
            self.video_tmp = None
            self.status.set_text("Grabación descartada")
            return
        if path.suffix.lower() != ".mp4":
            path = path.with_suffix(".mp4")
        try:
            shutil.move(str(self.video_tmp), str(path))
            self.status.set_text(f"Video guardado: {path}")
        except OSError as exc:
            self._error("No se pudo guardar el video", str(exc))
        finally:
            if self.video_tmp and self.video_tmp.exists():
                self.video_tmp.unlink(missing_ok=True)
            self.video_tmp = None

    def _save_send_capture(self) -> None:
        path = self._save_dialog("Guardar captura Send", "alphasmart-send.txt")
        if path:
            if path.suffix.lower() != ".txt":
                path = path.with_suffix(".txt")
            try:
                path.write_bytes(bytes(self.send_capture))
                self.status.set_text(f"Send guardado: {path}")
            except OSError as exc:
                self._error("No se pudo guardar Send", str(exc))
        self.send_capture.clear()

    def _show_paths(self, *_args) -> None:
        message = (
            f"Control queue:\n{self.control_file}\n\n"
            f"Event queue:\n{self.event_file}\n\n"
            f"LCD frame:\n{self.frame_file}\n\n"
            "Framebuffer esperado: 240×36 bytes, un byte por píxel (0/1)."
        )
        dialog = Gtk.MessageDialog(
            transient_for=self, modal=True, message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK, text="Rutas de AS2K Emulator"
        )
        dialog.format_secondary_text(message)
        dialog.run()
        dialog.destroy()

    def _show_shortcuts(self, *_args) -> None:
        shortcuts_path = Path(__file__).with_name("alphasmart_2000_shortcuts.txt")
        try:
            text = shortcuts_path.read_text(encoding="utf-8")
        except OSError as exc:
            self._error("No se pudo abrir la ayuda de atajos", str(exc))
            return

        window = Gtk.Window(title="AS2K Emulator — Atajos de teclado")
        window.set_transient_for(self)
        window.set_default_size(720, 560)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box.set_border_width(10)
        window.add(box)

        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        view = Gtk.TextView()
        view.set_editable(False)
        view.set_cursor_visible(False)
        view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        view.set_monospace(True)
        view.get_buffer().set_text(text)
        scroller.add(view)
        box.pack_start(scroller, True, True, 0)

        close = Gtk.Button(label="Cerrar")
        close.connect("clicked", lambda *_: window.destroy())
        box.pack_start(close, False, False, 0)
        window.show_all()

    def _show_about(self, *_args) -> None:
        dialog = Gtk.AboutDialog(transient_for=self, modal=True)
        dialog.set_program_name("AS2K Emulator")
        dialog.set_version("R1 UI scaffold")
        dialog.set_comments("Frontend estable para AlphaSmart 2000; motor de emulación derivado de MAME.")
        dialog.run()
        dialog.destroy()

    def _error(self, title: str, detail: str) -> None:
        dialog = Gtk.MessageDialog(
            transient_for=self, modal=True, message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK, text=title,
        )
        if detail:
            dialog.format_secondary_text(detail)
        dialog.run()
        dialog.destroy()

    def _on_delete_event(self, *_args) -> bool:
        if not self.recording:
            return False
        dialog = Gtk.MessageDialog(
            transient_for=self, modal=True, message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.NONE,
            text="Hay una grabación en curso",
        )
        dialog.add_button("Cancelar salida", Gtk.ResponseType.CANCEL)
        dialog.add_button("Descartar", Gtk.ResponseType.REJECT)
        dialog.add_button("Guardar…", Gtk.ResponseType.ACCEPT)
        response = dialog.run()
        dialog.destroy()
        if response == Gtk.ResponseType.CANCEL:
            return True
        if response == Gtk.ResponseType.ACCEPT:
            self._stop_recording()
            return self.recording
        self._finalize_recording()
        if self.video_tmp:
            self.video_tmp.unlink(missing_ok=True)
            self.video_tmp = None
        return False


class AS2KApplication(Gtk.Application):
    def __init__(self) -> None:
        super().__init__(application_id="com.customretrostuff.as2k")

    def do_activate(self) -> None:
        window = self.props.active_window
        if not window:
            window = AS2KWindow(self)
        window.show_all()
        window.present()


def main(argv=None) -> int:
    app = AS2KApplication()
    return app.run(argv or sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
