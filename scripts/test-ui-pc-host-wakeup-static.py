#!/usr/bin/env python3
"""Static contract regression for asynchronous PC host-edge wakeup.

Runs without ROM, host machine, new emulator or GUI. The dynamic/visual
acceptance is in scripts/test-ui-pc-host-wakeup-runtime.sh.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
cpp = (root / "src/mame/skeleton/alphasma.cpp").read_text()
ui = (root / "frontend/as2k_ui.py").read_text()
legacy = cpp.split("INPUT_CHANGED_MEMBER(asma2k_state::pc_connected_changed)", 1)[1].split(
    "bool asma2k_state::pc_connected()", 1)[0]
bridge = cpp.split('if (line == "PC ON" || line == "PC OFF")', 1)[1].split(
    'if (line == "PRINTER ON"', 1)[0]
irq = "m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE);"

def verify(name, truth):
    if not truth:
        raise AssertionError(name + ": FAILED")
    print("PASS: " + name)

verify("Both PC UI commands use one handler", 'line == "PC ON" || line == "PC OFF"' in cpp)
verify("Real external host state compared before applying UI override",
       "connected != pc_connected()" in bridge and
       bridge.index("connected != pc_connected()") < bridge.index("m_ui_pc_override = true"))
verify("IRQ only on genuine UI host state transition",
       irq in bridge.split("if (changed)", 1)[1].split('ui_emit_event(', 1)[0])
verify("Pause/Break fallback does not override UI ownership",
       "if (m_ui_pc_override || !BIT(oldval ^ newval, 0))" in legacy)
verify("Pause/Break genuine host edge wakes firmware", irq in legacy)
verify("No fake Send/key injected on host connection change",
       "ui_press_key(" not in bridge and "ui_set_key(" not in bridge and
       "m_ui_keyboard[" not in bridge and "KEY SEND" not in bridge)
verify("Send sink keeps actual on-disconnect capture boundary",
       "send_sink_end();" in bridge and "send_sink_end();" in legacy and
       'ui_emit_event("SEND_READY\\t"' in cpp)
verify("Matrix low write still releases HC11 IRQ",
       "m_maincpu->set_input_line(MC68HC11_IRQ_LINE, CLEAR_LINE);" in
       cpp.split("void alphasmart_state::kb_matrixl_w", 1)[1].split(
           "void alphasmart_state::kb_matrixh_w", 1)[0])
verify("Menus send PC ON and PC OFF through same bridge",
       'self._send_control(f"PC {\'ON\' if self.pc_connected else \'OFF\'}")' in ui)
verify("Existing Send test still covers two sends and disconnect",
       all(s in (root / "scripts/test-ui-send-runtime.sh").read_text()
           for s in ("PC ON", "KEY SEND", "PC OFF", "SEND_READY")))
print("AS2K PC HOST EDGE STATIC CONTRACT: PASS (10/10)")
