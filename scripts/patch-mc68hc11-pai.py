#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"HC11 PAI patch source mismatch: {label}")
    return text.replace(old, new, 1)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: patch-mc68hc11-pai.py MAME_TREE", file=sys.stderr)
        return 2

    root = pathlib.Path(sys.argv[1]).resolve()
    header = root / "src/devices/cpu/mc68hc11/mc68hc11.h"
    source = root / "src/devices/cpu/mc68hc11/mc68hc11.cpp"
    if not header.is_file() or not source.is_file():
        raise SystemExit("Compatible MC68HC11 source files not found")

    h = header.read_text(encoding="utf-8")
    c = source.read_text(encoding="utf-8")

    if "MC68HC11_PAI_LINE" in h:
        raise SystemExit("HC11 PAI support is already present; refusing double patch")

    h = replace_once(
        h,
        """enum {
	MC68HC11_IRQ_LINE           = 0,
	MC68HC11_XIRQ_LINE          = 1
};""",
        """enum {
	MC68HC11_IRQ_LINE           = 0,
	MC68HC11_XIRQ_LINE          = 1,
	MC68HC11_PAI_LINE           = 2
};""",
        "input-line enum",
    )
    h = replace_once(
        h,
        """	auto out_spi2_data_callback() { return m_spi2_data_output_cb.bind(); }""",
        """	auto out_spi2_data_callback() { return m_spi2_data_output_cb.bind(); }
	auto as2k_ir_tx_callback() { return m_as2k_ir_tx_cb.bind(); }
	auto as2k_ir_event_callback() { return m_as2k_ir_event_cb.bind(); }""",
        "AS2K IR callbacks",
    )
    h = replace_once(
        h,
        """	uint8_t pactl_r();
	void pactl_w(uint8_t data);
	uint8_t pactl_ddra_r();""",
        """	uint8_t pactl_r();
	void pactl_w(uint8_t data);
	uint8_t pacnt_r();
	void pacnt_w(uint8_t data);
	uint8_t pactl_ddra_r();""",
        "PACNT declarations",
    )
    h = replace_once(
        h,
        """	uint32_t m_irq_state;
	bool m_irq_asserted;

	memory_access<16, 0, 0, ENDIANNESS_BIG>::cache m_cache;""",
        """	uint32_t m_irq_state;
	bool m_irq_asserted;
	bool m_pai_asserted;

	memory_access<16, 0, 0, ENDIANNESS_BIG>::cache m_cache;""",
        "PAI state",
    )
    h = replace_once(
        h,
        """	devcb_read8 m_spi2_data_input_cb;
	devcb_write8 m_spi2_data_output_cb;""",
        """	devcb_read8 m_spi2_data_input_cb;
	devcb_write8 m_spi2_data_output_cb;
	devcb_write8 m_as2k_ir_tx_cb;
	devcb_write8 m_as2k_ir_event_cb;""",
        "AS2K IR callback members",
    )
    h = replace_once(
        h,
        """	uint8_t m_tflg2;
	uint8_t m_tmsk2;
	uint8_t m_pactl;
	uint8_t m_init;""",
        """	uint8_t m_tflg2;
	uint8_t m_tmsk2;
	uint8_t m_pactl;
	uint8_t m_pacnt;
	uint8_t m_init;""",
        "PACNT state",
    )

    c = replace_once(
        c,
        """	, m_spi2_data_input_cb(*this, 0xff)
	, m_spi2_data_output_cb(*this)""",
        """	, m_spi2_data_input_cb(*this, 0xff)
	, m_spi2_data_output_cb(*this)
	, m_as2k_ir_tx_cb(*this)
	, m_as2k_ir_event_cb(*this)""",
        "AS2K IR callback constructor",
    )
    c = replace_once(
        c,
        """	, m_program_config("program", ENDIANNESS_BIG, 8, 16, 0, address_map_constructor(FUNC(mc68hc11_cpu_device::internal_map), this))
	, m_irq_asserted(false)
	, m_port_input_cb(*this, 0xff)""",
        """	, m_program_config("program", ENDIANNESS_BIG, 8, 16, 0, address_map_constructor(FUNC(mc68hc11_cpu_device::internal_map), this))
	, m_irq_asserted(false)
	, m_pai_asserted(false)
	, m_port_input_cb(*this, 0xff)""",
        "constructor",
    )
    c = replace_once(
        c,
        """void mc68hc11_cpu_device::pactl_w(uint8_t data)
{
	m_pactl = data & 0x77;
}

uint8_t mc68hc11a1_device::pactl_ddra7_r()""",
        """void mc68hc11_cpu_device::pactl_w(uint8_t data)
{
	m_pactl = data & 0x77;
}

uint8_t mc68hc11_cpu_device::pacnt_r()
{
	return m_pacnt;
}

void mc68hc11_cpu_device::pacnt_w(uint8_t data)
{
	m_pacnt = data;
}

uint8_t mc68hc11a1_device::pactl_ddra7_r()""",
        "PACNT implementation",
    )
    c = replace_once(
        c,
        """	if (BIT(m_tflg2 & data, 6))
		set_irq_state(0x07, false);
	m_tflg2 &= ~data;""",
        """	if (BIT(m_tflg2 & data, 6))
		set_irq_state(0x07, false);
	if (BIT(m_tflg2 & data, 5))
		set_irq_state(0x11, false);
	if (BIT(m_tflg2 & data, 4))
		set_irq_state(0x12, false);
	m_tflg2 &= ~data;""",
        "TFLG2 PAI flags",
    )
    c = replace_once(
        c,
        """	if (BIT(m_tflg2 & (m_tmsk2 ^ data), 6))
		set_irq_state(0x07, BIT(data, 6));

	// TODO: prescaler bits are time-protected""",
        """	if (BIT(m_tflg2 & (m_tmsk2 ^ data), 6))
		set_irq_state(0x07, BIT(data, 6));
	if (BIT(m_tflg2 & (m_tmsk2 ^ data), 5))
		set_irq_state(0x11, BIT(data, 5));
	if (BIT(m_tflg2 & (m_tmsk2 ^ data), 4))
		set_irq_state(0x12, BIT(data, 4));

	// TODO: prescaler bits are time-protected""",
        "TMSK2 PAI masks",
    )
    c = replace_once(
        c,
        """	block(base + 0x25, base + 0x25).rw(FUNC(mc68hc11d0_device::tflg2_r), FUNC(mc68hc11d0_device::tflg2_w)); // TFLG2
	block(base + 0x26, base + 0x26).rw(FUNC(mc68hc11d0_device::pactl_ddra_r), FUNC(mc68hc11d0_device::pactl_ddra_w)); // PACTL
	block(base + 0x28, base + 0x28).r(FUNC(mc68hc11d0_device::spcr_r<0>)).nopw(); // SPCR""",
        """	block(base + 0x25, base + 0x25).rw(FUNC(mc68hc11d0_device::tflg2_r), FUNC(mc68hc11d0_device::tflg2_w)); // TFLG2
	block(base + 0x26, base + 0x26).rw(FUNC(mc68hc11d0_device::pactl_ddra_r), FUNC(mc68hc11d0_device::pactl_ddra_w)); // PACTL
	block(base + 0x27, base + 0x27).rw(FUNC(mc68hc11d0_device::pacnt_r), FUNC(mc68hc11d0_device::pacnt_w)); // PACNT
	block(base + 0x28, base + 0x28).r(FUNC(mc68hc11d0_device::spcr_r<0>)).nopw(); // SPCR""",
        "D0 PACNT map",
    )
    c = replace_once(
        c,
        """	save_item(NAME(m_tflg2));
	save_item(NAME(m_tmsk2));
	save_item(NAME(m_pactl));
	save_item(NAME(m_frc_base));""",
        """	save_item(NAME(m_tflg2));
	save_item(NAME(m_pai_asserted));
	save_item(NAME(m_tmsk2));
	save_item(NAME(m_pactl));
	save_item(NAME(m_pacnt));
	save_item(NAME(m_frc_base));""",
        "save state",
    )
    c = replace_once(
        c,
        """	m_tflg1 = 0;
	m_tflg2 = 0;
	m_tmsk2 = 3; // timer prescale
	m_pactl = 0;
	m_irq_state = 0x80000000 | (m_irq_state & 0x04000000);""",
        """	m_tflg1 = 0;
	m_tflg2 = 0;
	m_pai_asserted = false;
	m_tmsk2 = 3; // timer prescale
	m_pactl = 0;
	m_pacnt = 0;
	m_irq_state = 0x80000000 | (m_irq_state & 0x04000000);""",
        "reset state",
    )
    c = replace_once(
        c,
        """	case MC68HC11_XIRQ_LINE:
		set_irq_state(0x05, state != CLEAR_LINE);
		break;

	default:""",
        """	case MC68HC11_XIRQ_LINE:
		set_irq_state(0x05, state != CLEAR_LINE);
		break;

	case MC68HC11_PAI_LINE:
	{
		bool const level = state != CLEAR_LINE;
		bool const rising = !m_pai_asserted && level;
		bool const falling = m_pai_asserted && !level;
		m_pai_asserted = level;
		if ((BIT(m_pactl, 4) && rising) || (!BIT(m_pactl, 4) && falling))
		{
			m_tflg2 |= 0x10;
			if (BIT(m_tmsk2, 4))
				set_irq_state(0x12, true);

			if (BIT(m_pactl, 6) && !BIT(m_pactl, 5))
			{
				if (++m_pacnt == 0)
				{
					m_tflg2 |= 0x20;
					if (BIT(m_tmsk2, 5))
						set_irq_state(0x11, true);
				}
			}
		}
		break;
	}

	default:""",
        "PAI input",
    )

    observer = """			m_ppc = m_pc;
			debugger_instruction_hook(m_pc);"""
    observer_with_instruction_cb = """			m_ppc = m_pc;
			m_instruction_cb(m_pc);
			debugger_instruction_hook(m_pc);"""
    observed = """			m_ppc = m_pc;
			uint16_t const pc = m_ppc;
			if (pc == 0xd1ef)
				m_as2k_ir_tx_cb(m_d.d8.b);
			else if (pc == 0xd220)
				m_as2k_ir_event_cb(0x01);
			else if (pc == 0xd0d7)
				m_as2k_ir_event_cb(0x30);
			else if (pc == 0xd2dc)
				m_as2k_ir_event_cb(0x10);
			else if (pc == 0x9719)
				m_as2k_ir_event_cb(0x11);
			else if (pc == 0xd437)
				m_as2k_ir_event_cb(0x20);
			else if (pc == 0xd47d)
				m_as2k_ir_event_cb(0x21);
			debugger_instruction_hook(m_pc);"""
    observed_with_instruction_cb = """			m_ppc = m_pc;
			m_instruction_cb(m_pc);
			uint16_t const pc = m_ppc;
			if (pc == 0xd1ef)
				m_as2k_ir_tx_cb(m_d.d8.b);
			else if (pc == 0xd220)
				m_as2k_ir_event_cb(0x01);
			else if (pc == 0xd0d7)
				m_as2k_ir_event_cb(0x30);
			else if (pc == 0xd2dc)
				m_as2k_ir_event_cb(0x10);
			else if (pc == 0x9719)
				m_as2k_ir_event_cb(0x11);
			else if (pc == 0xd437)
				m_as2k_ir_event_cb(0x20);
			else if (pc == 0xd47d)
				m_as2k_ir_event_cb(0x21);
			debugger_instruction_hook(m_pc);"""
    if observer in c:
        c = c.replace(observer, observed, 1)
    elif observer_with_instruction_cb in c:
        c = c.replace(observer_with_instruction_cb, observed_with_instruction_cb, 1)
    else:
        raise SystemExit("HC11 PAI patch source mismatch: AS2K IR observer")

    header.write_text(h, encoding="utf-8")
    source.write_text(c, encoding="utf-8")
    print("AS2K HC11 PAI recovery patch: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
