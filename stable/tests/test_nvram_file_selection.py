#!/usr/bin/env python3
"""RAM-02: isolated regression for selected 128 KiB MAME NVRAM images.

No Gtk, proprietary ROM, physical device, or user's NVRAM is accessed.
"""
import ast
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace

SOURCE = Path(__file__).resolve().parents[1] / "frontend" / "as2k_session.py"
SIZE = 0x20000


def main():
    text = SOURCE.read_text(encoding="utf-8")
    tree = ast.parse(text, filename=str(SOURCE))
    klass = next(x for x in tree.body if isinstance(x, ast.ClassDef) and x.name == "Session")
    methods = {x.name: x for x in klass.body if isinstance(x, ast.FunctionDef)}
    for name in ("select_ram", "prepare_ram", "stop"):
        assert name in methods
    window = next(x for x in tree.body if isinstance(x, ast.ClassDef) and x.name == "ManagedWindow")
    for name in ("_choose_ram", "_default_ram", "_switch_ram"):
        assert any(isinstance(m, ast.FunctionDef) and m.name == name for m in window.body)
    source_menu = next(x for x in window.body if isinstance(x, ast.FunctionDef) and x.name == "_build_menu_bar")
    menu = ast.get_source_segment(text, source_menu)
    assert '"Abrir archivo RAM/NVRAM…"' in menu
    assert '"Usar RAM predeterminada"' in menu
    launcher = ast.get_source_segment(text, methods["start"])
    assert "self.prepare_ram()" in launcher
    assert '"-nvram_directory", str(self.nvram_directory)' in launcher
    assert 'self.stop()' in launcher
    assert '"ram_file": ""' in text
    assert "hashlib.sha256(before).digest() != self.external_digest" in text
    assert "self.pending_marker.unlink()" in text
    assert 'directory.mkdir(parents=True, exist_ok=True)' in text

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        globals_ = {"hashlib": hashlib, "os": os, "Path": Path,
                    "tempfile": tempfile, "subprocess": subprocess}
        globals_.update(DATA=tmp / "data", NVRAM_BYTES=SIZE,
                        NVRAM_FILE=tmp / "data/nvram/asma2k/nvram",
                        RAM_SELECTIONS=tmp / "data/nvram-selections",
                        EXIT_REQUEST=tmp / "exit.request")
        helpers = [x for x in tree.body if isinstance(x, ast.FunctionDef)
                   and x.name in ("valid_ram", "write_ram")]
        subset = ast.ClassDef(name="RamSession", bases=[], keywords=[],
                              body=[methods[n] for n in ("select_ram", "prepare_ram", "stop")],
                              decorator_list=[])
        module = ast.fix_missing_locations(ast.Module(
            body=helpers + [subset], type_ignores=[]))
        exec(compile(module, str(SOURCE), "exec"), globals_)
        Session = globals_["RamSession"]
        def new_session():
            s = Session()
            s.settings = {"ram_file": ""}
            s.save = lambda: None
            s.core = None
            s.log = None
            s.active_nvram = globals_["NVRAM_FILE"]
            s.nvram_directory = tmp / "data/nvram"
            s.external_ram = None
            s.external_digest = None
            s.pending_marker = None
            return s

        s = new_session()
        s.prepare_ram()
        default = globals_["NVRAM_FILE"]
        assert default.is_file() and default.stat().st_size == SIZE
        assert default.read_bytes() == bytes(SIZE)
        default.write_bytes(b"D" * SIZE)
        s.prepare_ram()
        assert default.read_bytes() == b"D" * SIZE, "Default RAM overwritten"

        bad = tmp / "bad.nv"
        bad.write_bytes(b"invalid")
        try:
            s.select_ram(bad)
        except ValueError:
            pass
        else:
            raise AssertionError("Accepted invalid RAM image")
        assert s.settings["ram_file"] == ""

        external = tmp / "user chosen RAM.nv"
        external.write_bytes(b"A" * SIZE)
        s.select_ram(external)
        assert s.settings["ram_file"] == str(external.resolve())
        s.prepare_ram()
        assert s.active_nvram.read_bytes() == b"A" * SIZE
        assert s.nvram_directory != tmp / "data/nvram"
        marker = s.pending_marker
        assert marker.exists()
        assert default.read_bytes() == b"D" * SIZE
        saved_workspace = s.active_nvram
        saved_workspace.write_bytes(b"R" * SIZE)
        try:
            s.prepare_ram()
        except RuntimeError:
            pass
        else:
            raise AssertionError("Concurrent/stale selected RAM was overwritten")
        assert saved_workspace.read_bytes() == b"R" * SIZE
        # Session object reset above; recover the same work session safely.
        s.active_nvram = saved_workspace
        s.external_ram = external
        s.external_digest = hashlib.sha256(b"A" * SIZE).digest()
        s.pending_marker = marker

        class Core:
            returncode = None
            def poll(self):
                return None
            def wait(self, timeout):
                assert timeout == 12
                assert globals_["EXIT_REQUEST"].read_text() == "EXIT\n"
                self.returncode = 0
                return 0
            def terminate(self): raise AssertionError("No SIGTERM")
            def kill(self): raise AssertionError("No SIGKILL")

        s.core = Core()
        s.stop()
        assert external.read_bytes() == b"R" * SIZE
        assert not marker.exists()
        assert default.read_bytes() == b"D" * SIZE
        backup = tmp / "data/ram-backups" / (
            hashlib.sha256(str(external).encode()).hexdigest() + ".before")
        assert backup.read_bytes() == b"A" * SIZE
        s2 = new_session()
        s2.settings = {"ram_file": str(external)}
        s2.prepare_ram()
        assert s2.active_nvram.read_bytes() == b"R" * SIZE
        # External conflict must not be overwritten; keep working copy.
        s2.active_nvram.write_bytes(b"S" * SIZE)
        external.write_bytes(b"X" * SIZE)
        s2.core = Core()
        try:
            s2.stop()
        except RuntimeError:
            pass
        else:
            raise AssertionError("External concurrent edit went undetected")
        assert external.read_bytes() == b"X" * SIZE
        assert s2.pending_marker.exists()
        assert s2.active_nvram.read_bytes() == b"S" * SIZE
        # Change the selection back without deleting the user's default.
        independent = new_session()
        independent.settings["ram_file"] = str(external)
        independent.select_ram(None)
        independent.prepare_ram()
        assert independent.active_nvram == default
        assert default.read_bytes() == b"D" * SIZE

    print("AS2K_STABLE_RAM02_SELECT_DEFAULT_AND_REMEMBER_PASS")
    print("AS2K_STABLE_RAM02_EXTERNAL_SYNC_BACKUP_AND_CONFLICT_PASS")


if __name__ == "__main__":
    main()
