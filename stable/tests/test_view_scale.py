#!/usr/bin/env python3
"""Headless regression for AS2K Stable View scale; no GTK display required.

Usage: python3 -B stable/tests/test_view_scale.py
The real GTK drawing method is loaded from the source AST, while the cairo
canvas and window are faked. This verifies geometry and UI callback effects,
not a live user-driven Gtk/GDK window.
"""
from __future__ import annotations
import ast
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "frontend" / "as2k_ui.py"
SESSION = ROOT / "frontend" / "as2k_session.py"
LCD_WIDTH, LCD_HEIGHT = 240, 36


def method(name):
    source = ast.parse(UI.read_text())
    klass = next(x for x in source.body if isinstance(x, ast.ClassDef) and x.name == "AS2KWindow")
    func = next(x for x in klass.body if isinstance(x, ast.FunctionDef) and x.name == name)
    module = ast.Module(body=[func], type_ignores=[])
    context = {
        "LCD_WIDTH": LCD_WIDTH,
        "LCD_HEIGHT": LCD_HEIGHT,
        "Gtk": SimpleNamespace(DrawingArea=object, RadioMenuItem=object, CheckMenuItem=object),
        "Gdk": SimpleNamespace(cairo_set_source_pixbuf=lambda *_: None),
        "__name__": "__scale_test__",
    }
    exec(compile(module, str(UI), "exec", dont_inherit=True), context)
    return context[name]


class Cairo:
    def __init__(self):
        self.ratio = None

    def save(self): pass
    def translate(self, x, y): pass
    def scale(self, x, y):
        assert x == y
        self.ratio = x
    def get_source(self): return self
    def set_filter(self, method): pass
    def paint(self): pass
    def restore(self): pass


class Area:
    def __init__(self, width=960, height=288):
        self.alloc = SimpleNamespace(width=width, height=height)
        self.size = None
        self.draws = 0

    def get_allocation(self): return self.alloc
    def set_size_request(self, width, height): self.size = (width, height)
    def queue_draw(self): self.draws += 1


class Window:
    lcd_pixbuf = object()
    def __init__(self):
        self.lcd_area = Area()
        self.ui_scale = 1.0
        self._lcd_fullscreen = False
        self.resizes = 0
        self.fullscreen_calls = []
    def queue_resize(self): self.resizes += 1
    def fullscreen(self): self.fullscreen_calls.append(True)
    def unfullscreen(self): self.fullscreen_calls.append(False)


def test():
    draw = method("_draw_lcd")
    select = method("_on_scale_selected")
    set_scale = method("_set_scale")
    toggle_fullscreen = method("_toggle_fullscreen")
    win = Window()
    for factor, expected_size in (
        (1.0, (240, 36)), (1.5, (360, 54)), (2.0, (480, 72))
    ):
        active = SimpleNamespace(get_active=lambda: True)
        select(win, active, factor)
        assert win.lcd_area.size == expected_size
        assert win.lcd_area.draws > 0
        canvas = Cairo()
        assert draw(win, win.lcd_area, canvas) is False
        assert canvas.ratio == factor, (factor, canvas.ratio)
    assert win.resizes == 3

    # Gtk can allocate more space than the size request. The selected zoom
    # must still govern painting instead of stretching to the spare space.
    win.lcd_area.alloc = SimpleNamespace(width=960, height=288)
    canvas = Cairo()
    draw(win, win.lcd_area, canvas)
    assert canvas.ratio == 2.0

    # When the widget is constrained, shrink to fit rather than clipping.
    win.lcd_area.alloc = SimpleNamespace(width=300, height=45)
    canvas = Cairo()
    draw(win, win.lcd_area, canvas)
    assert canvas.ratio == 1.25

    win.lcd_area.alloc = SimpleNamespace(width=960, height=288)
    toggle_fullscreen(win, SimpleNamespace(get_active=lambda: True))
    canvas = Cairo()
    draw(win, win.lcd_area, canvas)
    assert canvas.ratio == 4.0
    toggle_fullscreen(win, SimpleNamespace(get_active=lambda: False))
    canvas = Cairo()
    draw(win, win.lcd_area, canvas)
    assert canvas.ratio == 2.0
    assert win.fullscreen_calls == [True, False]

    session = SESSION.read_text()
    assert 'self._scale_menu_items[2.0].set_active(True)' in session
    assert 'self.lcd_area.set_size_request(ui.LCD_WIDTH * 2' not in session
    assert 'self._scale_menu_items[scale] = item' in UI.read_text()
    print("AS2K_STABLE_VIEW_100_150_200_HEADLESS_PASS")


if __name__ == "__main__":
    test()
