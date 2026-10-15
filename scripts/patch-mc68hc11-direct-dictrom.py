#!/usr/bin/env python3
"""Port DIAG's HC11 post-bootstrap reset release to the Stable build.

The donor MAME source is restored after compilation by build-stable-core.sh.
"""
from pathlib import Path
import sys

def once(text, old, new, label):
    if text.count(old) != 1:
        raise SystemExit("AS2K Direct DictROM patch mismatch: " + label)
    return text.replace(old, new, 1)

def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch-mc68hc11-direct-dictrom.py MAME_TREE")
    root = Path(sys.argv[1]).resolve()
    hpath = root / "src/devices/cpu/mc68hc11/mc68hc11.h"
    cpath = root / "src/devices/cpu/mc68hc11/mc68hc11.cpp"
    if not hpath.is_file() or not cpath.is_file():
        raise SystemExit("Missing donor HC11 files")
    h, c = hpath.read_text(), cpath.read_text()
    if "as2k_direct_dictrom_entry" in h or "as2k_direct_dictrom_entry" in c:
        raise SystemExit("Refuse double patch")
    h = once(h,
        "\tauto instruction_callback() { return m_instruction_cb.bind(); }",
        "\tauto instruction_callback() { return m_instruction_cb.bind(); }\n"
        "\t// DIAG-proven post-reset direct DictROM entry.\n"
        "\tvoid as2k_direct_dictrom_entry(uint16_t pc);",
        "public entry")
    c = once(c,
        "void mc68hc11_cpu_device::execute_set_input(int inputnum, int state)",
        """void mc68hc11_cpu_device::as2k_direct_dictrom_entry(uint16_t pc)
{
	if (pc != 0x4000)
		fatalerror("AS2K Direct DictROM entry requires $4000");
	// Derived from DIAG diagnostic_bootstrap_entry(): release both
	// pending RESET and reset-wait, then enter external DictROM.
	m_config |= 0x04;
	m_irq_state = 0;
	m_irq_asserted = false;
	m_wait_state = 0;
	m_stop_state = 0;
	m_ccr = CC_X | CC_I | CC_S;
	m_sp = 0x00c3;
	m_d.d8.a = 0x04;
	m_d.d8.b = 0;
	m_ix = 0;
	m_iy = 0;
	m_pc = pc;
	m_ppc = pc;
}


void mc68hc11_cpu_device::execute_set_input(int inputnum, int state)""",
        "DIAG post-bootstrap reset release")
    # Check both transformations before either source file is written.
    hpath.write_text(h)
    cpath.write_text(c)
    print("AS2K HC11 Direct DictROM: STATIC PORT PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
