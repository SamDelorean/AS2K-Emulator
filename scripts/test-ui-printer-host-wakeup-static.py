#!/usr/bin/env python3
"""Static regression for wired-printer host-edge wakeup in AS2K Stable.

No ROM, no MAME invocation, no changes to AS2K-DIAG or installed devices.
The runtime/visual printer attach-detach test is still required separately.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cpp = (root / "src/mame/skeleton/alphasma.cpp").read_text()
ui = (root / "frontend/as2k_ui.py").read_text()
irq = "m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE);"

def check(name, condition):
    assert condition, "FAIL: " + name
    print("PASS: " + name)

printer = cpp.split('if (line == "PRINTER ON" || line == "PRINTER OFF")', 1)[1].split(
    'if (line == "IR ON"', 1)[0]
pc = cpp.split('if (line == "PC ON" || line == "PC OFF")', 1)[1].split(
    'if (line == "PRINTER ON"', 1)[0]
pa = cpp.split("uint8_t asma2k_state::asma2k_port_a_r()", 1)[1].split(
    "struct as2k_set2_key_map", 1)[0]

check("Same handler implements PRINTER ON and PRINTER OFF",
      'line == "PRINTER ON" || line == "PRINTER OFF"' in cpp)
check("Printer edge is compared before applying new state",
      "connected != m_ui_printer_connected" in printer and
      printer.index("connected != m_ui_printer_connected") <
      printer.index("m_ui_printer_connected = connected;"))
on_edge = printer.split("if (changed)", 1)[1].split('ui_emit_event(', 1)[0]
check("Exactly one HC11 IRQ within the changed-printer guard",
      on_edge.count(irq) == 1 and printer.count(irq) == 1)
check("IRQ is after printer state update, not before",
      printer.index("m_ui_printer_connected = connected;") < printer.index(irq))
check("A diagnostic marker distinguishes printer from PC",
      'AS2K_PRINTER_HOST_EDGE_WAKE_IRQ attached=%u' in on_edge and
      'AS2K_PC_HOST_EDGE_WAKE_IRQ' in pc)
check("Do not invent a keyboard press or Send on printer connection",
      not any(token in printer for token in (
          "ui_press_key(", "ui_set_key(", 'KEY PRINT', 'KEY SEND',
          "m_ui_keyboard[")))
check("Printer disconnect retains outstanding-frame and job cleanup",
      all(token in printer for token in (
          "if (!connected)", "m_printer_frame_active = false;",
          "m_printer_frame_timer->adjust(attotime::never);",
          "printer_capture_end(false);")))
check("Printer physical host sense still uses PA0 and PC uses PA0+PA2",
      "if (m_ui_printer_connected)" in pa and "data |= 0x01;" in pa and
      "else if (pc_connected())" in pa and "data |= 0x05;" in pa)
check("UI keeps PC and printer attachments mutually exclusive",
      "if self.printer_connected and self.pc_connected:" in ui and
      "if self.pc_connected and self.printer_connected:" in ui and
      'self._send_control(f"PRINTER {\'ON\' if self.printer_connected else \'OFF\'}")' in ui)
check("Physical Print bytes and PCL completion still present",
      "m_printer_capture->write(&byte, 1);" in cpp and
      "printer_capture_end(true);" in cpp and
      "printer_frame_done" in cpp)
check("PC host-edge and Save As logic are preserved",
      irq in pc and "send_sink_end();" in pc and
      'ui_emit_event("SEND_READY\\t"' in cpp)
print("AS2K STABLE PRINTER HOST-EDGE STATIC REGRESSION: PASS (11/11)")
