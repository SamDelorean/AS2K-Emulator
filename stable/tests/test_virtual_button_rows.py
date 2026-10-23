#!/usr/bin/env python3
"""Static regression: AS2K Stable virtual controls use exactly two rows.

No Gtk display is required. Physical ESC keyboard support must remain.
"""
import ast
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "frontend" / "as2k_ui.py"


def main():
    source = SOURCE.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(SOURCE))
    ui = next(node for node in tree.body
              if isinstance(node, ast.ClassDef) and node.name == "AS2KWindow")
    keys = next(node for node in ui.body
                if isinstance(node, ast.FunctionDef) and node.name == "_virtual_keys")
    keys.decorator_list = []
    namespace = {}
    exec(compile(ast.Module(body=[keys], type_ignores=[]), str(SOURCE), "exec"), namespace)
    actual = namespace["_virtual_keys"]()
    expected = (
        [(f"F{i}", f"KEY F{i}") for i in range(1, 9)] +
        [("Print", "KEY PRINT"), ("Spell", "KEY SPELL"),
         ("Find", "KEY FIND"), ("Clear", "KEY CLEAR"),
         ("Home", "KEY HOME"), ("End", "KEY END"),
         ("Enter", "KEY ENTER"), ("Send", "KEY SEND")]
    )
    assert actual == expected, (actual, expected)
    assert len(actual) == 16
    assert "Escape" in source and '"Escape": "ESC"' in source
    ui_build = next(node for node in ui.body
                    if isinstance(node, ast.FunctionDef) and node.name == "_build_ui")
    fragment = ast.get_source_segment(source, ui_build)
    assert "key_rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)" in fragment
    assert "key_scroller.add(key_rows)" in fragment
    assert "key_commands = self._virtual_keys()" in fragment
    assert "for row_keys in (key_commands[:8], key_commands[8:]):" in fragment
    assert "row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)" in fragment
    assert "key_rows.pack_start(row, False, False, 0)" in fragment
    assert "button.connect(\"clicked\", self._on_virtual_key, command)" in fragment
    assert "row.pack_start(button, False, False, 0)" in fragment
    assert "keys.pack_start(button" not in fragment
    assert actual[:8] == expected[:8] and actual[8:] == expected[8:]
    # Both Word-like lines must be centered; GTK shares the widest
    # natural button width across all 16 labels, with a 72x34 minimum.
    assert "key_rows.set_halign(Gtk.Align.CENTER)" in fragment
    assert "row.set_halign(Gtk.Align.CENTER)" in fragment
    assert "key_sizes = Gtk.SizeGroup.new(Gtk.SizeGroupMode.HORIZONTAL)" in fragment
    assert "button.set_size_request(72, 34)" in fragment
    assert "key_sizes.add_widget(button)" in fragment
    print("AS2K_STABLE_BUTTON_TWO_ROWS_NO_ESC_STATIC_PASS")
    print("AS2K_STABLE_BUTTON_CENTERED_UNIFORM_STATIC_PASS")


if __name__ == "__main__":
    main()
