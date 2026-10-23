#!/usr/bin/env python3
"""Headless safety regression for native MAME NVRAM persistence.

Exercises the actual Session.stop method without importing GTK, opening
ROM images, modifying a user's NVRAM, or launching MAME.
"""
import ast
import io
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "frontend" / "as2k_session.py"


def find_method(tree, class_name, method_name):
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == class_name)
    return next(n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == method_name)


def main():
    src = SOURCE.read_text(encoding="utf-8")
    tree = ast.parse(src, filename=str(SOURCE))
    stop = find_method(tree, "Session", "stop")
    start = find_method(tree, "Session", "start")
    window_exit = find_method(tree, "ManagedWindow", "_on_delete_event")

    stop_source = ast.get_source_segment(src, stop)
    start_source = ast.get_source_segment(src, start)
    exit_source = ast.get_source_segment(src, window_exit)
    assert ".terminate(" not in stop_source
    assert ".kill(" not in stop_source
    assert 'EXIT_REQUEST.write_text("EXIT\\n"' in stop_source
    assert "self.core.wait(timeout=12)" in stop_source
    assert "not valid_ram(self.active_nvram)" in stop_source
    assert "NVRAM_BYTES = 0x20000" in src
    assert "atomic_write(EXIT_SCRIPT, EXIT_LUA)" in start_source
    assert '"-autoboot_script", str(EXIT_SCRIPT)' in start_source
    assert 'core_env["AS2K_EXIT_REQUEST"] = str(EXIT_REQUEST)' in start_source
    assert 'session.stop()' in exit_source
    assert "return True" in exit_source

    assignments = {n.targets[0].id: n.value
                   for n in tree.body if isinstance(n, ast.Assign)
                   and len(n.targets) == 1 and isinstance(n.targets[0], ast.Name)}
    lua = ast.literal_eval(assignments["EXIT_LUA"])
    assert lua.lstrip().startswith('local request = assert(os.getenv("AS2K_EXIT_REQUEST"))')
    assert 'emu.register_frame_done' in lua
    assert "manager.machine:exit()" in lua
    assert lua.count("manager.machine:exit()") == 1

    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        request = home / "exit.request"
        nvram = home / "nvram" / "asma2k" / "nvram"
        size = 0x20000
        symbols = {
            "EXIT_REQUEST": request, "NVRAM_BYTES": size,
            "valid_ram": lambda path: path.is_file() and path.stat().st_size == size,
            "subprocess": subprocess, "RuntimeError": RuntimeError,
        }
        exec(compile(ast.Module(body=[stop], type_ignores=[]), str(SOURCE), "exec"), symbols)
        run_stop = symbols["stop"]

        class Core:
            returncode = None
            def __init__(self, behavior):
                self.behavior = behavior
            def poll(self):
                return None
            def wait(self, timeout):
                assert timeout == 12 and request.read_text() == "EXIT\n"
                if self.behavior == "timeout":
                    raise subprocess.TimeoutExpired("core", timeout)
                if self.behavior == "bad":
                    self.returncode = 1
                    return 1
                if self.behavior == "missing":
                    self.returncode = 0
                    return 0
                nvram.parent.mkdir(parents=True, exist_ok=True)
                nvram.write_bytes(bytes(size))
                self.returncode = 0
                return 0
            def terminate(self):
                raise AssertionError("SIGTERM is forbidden")
            def kill(self):
                raise AssertionError("SIGKILL is forbidden")

        successful = SimpleNamespace(core=Core("ok"), log=io.StringIO(),
                                     active_nvram=nvram, external_ram=None)
        run_stop(successful)
        assert successful.core is None and successful.log is None
        assert nvram.stat().st_size == size

        for case in ("timeout", "bad", "missing"):
            request.unlink(missing_ok=True)
            nvram.unlink(missing_ok=True)
            candidate = SimpleNamespace(core=Core(case), log=io.StringIO(),
                                        active_nvram=nvram, external_ram=None)
            try:
                run_stop(candidate)
            except RuntimeError:
                assert candidate.core is not None
            else:
                raise AssertionError("Unsafe stop succeeded: " + case)

    print("AS2K_STABLE_NVRAM_NATIVE_SHUTDOWN_STATIC_PASS")
    print("AS2K_STABLE_NVRAM_SESSION_STOP_MOCK_PASS")


if __name__ == "__main__":
    main()
