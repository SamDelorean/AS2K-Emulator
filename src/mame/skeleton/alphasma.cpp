// license:BSD-3-Clause
// copyright-holders:Sandro Ronco
/***************************************************************************

        AlphaSmart Pro

        driver by Sandro Ronco

    TODO:
    - ADB and PS/2
    - charset ROM is wrong
    - asma2k reads from nonexistent internal register at 0x0001
      (probably a bug, since the same code exists in both BIOSes)

****************************************************************************/

#include "emu.h"
#include "bus/generic/carts.h"
#include "bus/generic/slot.h"
#include "fileio.h"
#include "emuopts.h"
#include "cpu/mc68hc11/mc68hc11.h"
#include "machine/nvram.h"
#include "video/hd44780.h"
#include "emupal.h"
#include "screen.h"

#include <array>
#include <cstdlib>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <sstream>
#include <string_view>
#include <vector>


namespace {

class alphasmart_state : public driver_device
{
public:
	alphasmart_state(const machine_config &mconfig, device_type type, const char *tag)
		: driver_device(mconfig, type, tag)
		, m_maincpu(*this, "maincpu")
		, m_lcdc(*this, "ks0066_%u", 0U)
		, m_nvram(*this, "nvram")
		, m_nvram_base(*this, "nvram", 0x20000, ENDIANNESS_BIG)
		, m_rambank(*this, "rambank")
		, m_keyboard(*this, "COL.%u", 0)
		, m_battery_status(*this, "BATTERY")
	{
	}

	void alphasmart(machine_config &config);

	DECLARE_INPUT_CHANGED_MEMBER(kb_irq);

protected:
	required_device<mc68hc11_cpu_device> m_maincpu;
	required_device_array<ks0066_device, 2> m_lcdc;
	required_device<nvram_device> m_nvram;
	memory_share_creator<uint8_t> m_nvram_base;
	required_memory_bank m_rambank;
	required_ioport_array<16> m_keyboard;
	required_ioport m_battery_status;

	virtual void machine_start() override ATTR_COLD;
	virtual void machine_reset() override ATTR_COLD;
	void alphasmart_palette(palette_device &palette) const;
	virtual uint32_t screen_update(screen_device &screen, bitmap_ind16 &bitmap, const rectangle &cliprect);

	uint8_t kb_r();
	void kb_matrixl_w(uint8_t data);
	void kb_matrixh_w(uint8_t data);
	uint8_t port_a_r();
	virtual void port_a_w(uint8_t data);
	uint8_t port_d_r();
	void port_d_w(uint8_t data);
	void update_lcdc(bool lcdc0, bool lcdc1);

	void alphasmart_mem(address_map &map) ATTR_COLD;

	uint8_t           m_matrix[2];
	uint8_t           m_port_a;
	uint8_t           m_port_d;
	std::unique_ptr<bitmap_ind16> m_tmp_bitmap;
	std::array<uint8_t, 16> m_ui_keyboard{};
	virtual void screen_updated(bitmap_ind16 const &bitmap) { }
};

enum class as2k_pc_key : uint8_t
{
	none,
	space, tab, enter, backspace, caps_lock,
	left_shift, right_shift, left_ctrl, right_ctrl, left_alt, right_alt,
	a, b, c, d, e, f, g, h, i, j, k, l, m,
	n, o, p, q, r, s, t, u, v, w, x, y, z,
	num_0, num_1, num_2, num_3, num_4, num_5, num_6, num_7, num_8, num_9,
	grave, minus, equals, lbrace, rbrace, backslash, semicolon, quote, comma, period, slash,
	kp_0, kp_1, kp_2, kp_3, kp_4, kp_5, kp_6, kp_7, kp_8, kp_9
};

class asma2k_state : public alphasmart_state
{
public:
	asma2k_state(const machine_config &mconfig, device_type type, const char *tag)
		: alphasmart_state(mconfig, type, tag)
		, m_io_view(*this, "io")
		, m_firmware(*this, "firmware")
		, m_dictrom(*this, "dictrom")
		, m_pc_connected(*this, "PC_CONNECTED")
		, m_boot_mode(*this, "BOOT_MODE")
	{
	}

	void asma2k(machine_config &config);
	DECLARE_INPUT_CHANGED_MEMBER(pc_connected_changed);

protected:
	virtual void machine_start() override ATTR_COLD;
	virtual void machine_reset() override ATTR_COLD;

private:
	DECLARE_DEVICE_IMAGE_LOAD_MEMBER(firmware_load);
	DECLARE_DEVICE_IMAGE_LOAD_MEMBER(dictrom_load);
	uint8_t firmware_r(offs_t offset);
	uint8_t dictrom_r(offs_t offset);
	bool set_cpu_state(char const *symbol, uint64_t value);
	void apply_direct_dictrom_bootstrap();
	void lcd_ctrl_w(uint8_t data);
	uint8_t asma2k_port_a_r();
	void asma2k_port_d_w(uint8_t data);
	virtual void port_a_w(uint8_t data) override;
	void pc_clock_rising(bool data);
	void pc_set2_byte(uint8_t data);
	void pc_key_event(as2k_pc_key key, bool pressed);
	void pc_keyboard_reset();
	void send_sink_begin();
	void send_sink_codepoint(char32_t codepoint);
	void send_sink_end();
	bool pc_connected();
	TIMER_CALLBACK_MEMBER(printer_frame_done);
	void printer_capture_byte(uint8_t byte);
	void printer_capture_end(bool complete);
	void ir_tx_byte_w(uint8_t data);
	void ir_event_w(uint8_t event);
	void ir_capture_begin(char const *kind);
	void ir_capture_end(bool complete);
	void ir_ui_flush();
	void ir_frame_byte(uint8_t data);
	void ir_peer_begin();
	void ir_peer_stop();
	void ir_peer_send_xid();
	void ir_peer_send_xid_response();
	void ir_peer_send_snrm();
	void ir_peer_send_ua();
	void ir_peer_send_rr(uint8_t nr, bool final_bit);
	void ir_peer_send_i(std::vector<uint8_t> const &info);
	void ir_peer_send_frame(std::vector<uint8_t> const &body);
	void ir_peer_on_tx_frame(std::vector<uint8_t> const &frame);
	void ir_peer_drive(bool high);
	TIMER_CALLBACK_MEMBER(ir_peer_timer);
	void ui_bridge_init();
	void ui_bridge_poll();
	void ui_process_command(std::string const &line);
	void ui_emit_event(std::string const &line);
	void ui_write_frame(bitmap_ind16 const &bitmap);
	bool ui_press_key(std::string_view name);
	virtual void screen_updated(bitmap_ind16 const &bitmap) override;
	TIMER_CALLBACK_MEMBER(ui_bridge_tick);
	TIMER_CALLBACK_MEMBER(ui_key_release);

	void asma2k_mem(address_map &map) ATTR_COLD;

	memory_view m_io_view;
	required_device<generic_slot_device> m_firmware;
	required_device<generic_slot_device> m_dictrom;
	required_ioport m_pc_connected;
	required_ioport m_boot_mode;

	uint8_t m_lcd_ctrl = 0;
	uint8_t m_dict_bank = 0;
	uint16_t m_pc_frame = 0;
	uint8_t m_pc_frame_bits = 0;
	bool m_pc_set2_break = false;
	bool m_pc_set2_extended = false;
	uint8_t m_pc_set2_e1_remaining = 0;
	bool m_pc_lshift = false;
	bool m_pc_rshift = false;
	bool m_pc_lctrl = false;
	bool m_pc_rctrl = false;
	bool m_pc_lalt = false;
	bool m_pc_ralt = false;
	bool m_pc_caps_lock = false;
	// A host-side Windows ANSI keyboard profile; firmware only emits Set-2.
	// Numeric composition is tracked across make/break events, not ROM PCs.
	bool m_pc_alt_numeric_valid = false;
	uint8_t m_pc_alt_numeric_count = 0;
	char m_pc_alt_numeric_digits[4]{};
	bool m_send_sink_active = false;
	bool m_send_sink_had_data = false;
	uint64_t m_send_session_serial = 0;
	std::unique_ptr<emu_file> m_send_sink;

	emu_timer *m_printer_frame_timer = nullptr;
	bool m_printer_frame_active = false;
	uint8_t m_printer_edge_count = 0;
	uint64_t m_printer_start_tick = 0;
	std::array<uint64_t, 32> m_printer_edge_ticks{};
	std::array<uint8_t, 32> m_printer_edge_levels{};
	unsigned m_printer_capture_bytes = 0;
	uint64_t m_printer_session_serial = 0;
	std::array<uint8_t, 7> m_printer_tail{};
	uint8_t m_printer_tail_count = 0;
	std::unique_ptr<emu_file> m_printer_capture;

	bool m_ir_capture_active = false;
	bool m_ir_frame_active = false;
	bool m_ir_escape = false;
	uint32_t m_ir_session_bytes = 0;
	uint32_t m_ir_frame_count = 0;
	std::string m_ir_session_kind;
	std::vector<uint8_t> m_ir_frame;
	std::array<uint8_t, 16> m_ir_ui_batch{};
	uint8_t m_ir_ui_batch_count = 0;

	// Recovered virtual IrDA peer.  This is the already-validated PA7/PAI
	// optical peer, retained without the old diagnostic TXT/PDF file sinks.
	emu_timer *m_ir_peer_timer = nullptr;
	std::vector<uint8_t> m_ir_peer_raw;
	size_t m_ir_peer_byte = 0;
	uint8_t m_ir_peer_bit = 0;
	bool m_ir_peer_pulse_end = false;
	bool m_ir_peer_active = false;
	bool m_ir_peer_level = true;
	bool m_ir_peer_send_session = false;
	bool m_ir_peer_print_session = false;
	bool m_ir_peer_primary = true;
	bool m_ir_peer_print_discovery_replied = false;
	bool m_ir_peer_file_receive = false;
	uint32_t m_ir_peer_text_bytes = 0;
	uint32_t m_ir_print_bytes = 0;
	bool m_ir_print_complete = false;
	uint8_t m_ir_peer_stage = 0;
	uint8_t m_ir_peer_xid_slot = 0;
	uint8_t m_ir_peer_pending = 0;
	uint8_t m_ir_peer_nr = 0;
	uint8_t m_ir_peer_ns = 0;
	uint8_t m_ir_peer_connection_address = 0x02;
	uint32_t m_ir_peer_target = 0;

	bool m_ui_pc_override = false;
	bool m_ui_pc_connected = false;
	bool m_ui_printer_connected = false;
	bool m_ui_ir_enabled = false;
	std::string m_ui_control_path;
	std::string m_ui_event_path;
	std::string m_ui_frame_path;
	std::streamoff m_ui_control_offset = 0;
	emu_timer *m_ui_bridge_timer = nullptr;
	emu_timer *m_ui_key_release_timer = nullptr;
	int m_ui_key_col = -1;
	uint8_t m_ui_key_mask = 0;
};

INPUT_CHANGED_MEMBER(alphasmart_state::kb_irq)
{
	// IRQ on every key transition
	m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE);
}

uint8_t alphasmart_state::kb_r()
{
	uint16_t matrix = (m_matrix[1]<<8) | m_matrix[0];
	uint8_t data = 0xff;

	for(int i=0; i<16; i++)
		if (!(matrix & (1<<i)))
			data &= m_keyboard[i]->read() & m_ui_keyboard[i];

	return data;
}

void alphasmart_state::kb_matrixl_w(uint8_t data)
{
	m_matrix[0] = data;
	m_maincpu->set_input_line(MC68HC11_IRQ_LINE, CLEAR_LINE);
}

void alphasmart_state::kb_matrixh_w(uint8_t data)
{
	m_matrix[1] = data;
}

uint8_t alphasmart_state::port_a_r()
{
	return (m_port_a & 0xfd) | (m_battery_status->read() << 1);
}

void alphasmart_state::update_lcdc(bool lcdc0, bool lcdc1)
{
	if (m_matrix[1] & 0x04)
	{
		uint8_t lcdc_data = 0;

		if (lcdc0)
			lcdc_data |= m_lcdc[0]->read(BIT(m_matrix[1], 1));

		if (lcdc1)
			lcdc_data |= m_lcdc[1]->read(BIT(m_matrix[1], 1));

		m_port_d = (m_port_d & 0xc3) | (lcdc_data>>2);
	}
	else
	{
		uint8_t lcdc_data = (m_port_d<<2) & 0xf0;

		if (lcdc0)
			m_lcdc[0]->write(BIT(m_matrix[1], 1), lcdc_data);

		if (lcdc1)
			m_lcdc[1]->write(BIT(m_matrix[1], 1), lcdc_data);
	}
}

void alphasmart_state::port_a_w(uint8_t data)
{
	uint8_t changed = (m_port_a ^ data) & data;
	update_lcdc(changed & 0x80, changed & 0x20);
	m_rambank->set_entry(((data>>3) & 0x01) | ((data>>4) & 0x02));
	m_port_a = data;
}

uint8_t alphasmart_state::port_d_r()
{
	return m_port_d;
}

void alphasmart_state::port_d_w(uint8_t data)
{
	m_port_d = data;
}


void alphasmart_state::alphasmart_mem(address_map &map)
{
	map.unmap_value_high();
	map(0x0000, 0x7fff).bankrw("rambank");
	map(0x8000, 0xffff).rom().region("maincpu", 0);
	map(0x8000, 0x8000).rw(FUNC(alphasmart_state::kb_r), FUNC(alphasmart_state::kb_matrixh_w));
	map(0xc000, 0xc000).w(FUNC(alphasmart_state::kb_matrixl_w));
}

void asma2k_state::lcd_ctrl_w(uint8_t data)
{
	uint8_t changed = (m_lcd_ctrl ^ data) & data;
	update_lcdc(changed & 0x01, changed & 0x02);
	m_dict_bank = ((m_port_a & 0x30) >> 3) | ((data & 0x80) >> 7);
	m_lcd_ctrl = data;
}

uint8_t asma2k_state::asma2k_port_a_r()
{
	uint8_t data = (m_port_a & 0xfd) | (m_battery_status->read() << 1);

	// Wired printer and PC keyboard share the same physical host-side path in
	// the validated AS2000 model.  Clear the host-sense bits first, then expose
	// exactly one hardware condition.  The GTK front-end also prevents the two
	// attachment toggles from remaining active simultaneously.
	data &= ~uint8_t(0x05);
	if (m_ui_printer_connected)
		data |= 0x01; // Wired printer ready: PA0 high.
	else if (pc_connected())
		data |= 0x05; // PC keyboard: PA2 and idle PA0 high.

	// PA7 is the IrDA optical receiver / pulse-accumulator input.  Idle is
	// HIGH.  During an active recovered peer transaction its driven level is
	// reflected both here and on MC68HC11_PAI_LINE.
	bool const ir_high = m_ui_ir_enabled && m_ir_peer_active ? m_ir_peer_level : true;
	data = (data & 0x7f) | (ir_high ? 0x80 : 0x00);
	return data;
}

struct as2k_set2_key_map
{
	uint8_t code;
	bool extended;
	as2k_pc_key key;
};

static constexpr as2k_set2_key_map s_set2_keys[] =
{
	{ 0x0d, false, as2k_pc_key::tab },        { 0x0e, false, as2k_pc_key::grave },
	{ 0x11, false, as2k_pc_key::left_alt },   { 0x11, true,  as2k_pc_key::right_alt },
	{ 0x12, false, as2k_pc_key::left_shift }, { 0x14, false, as2k_pc_key::left_ctrl },
	{ 0x14, true,  as2k_pc_key::right_ctrl }, { 0x15, false, as2k_pc_key::q },
	{ 0x16, false, as2k_pc_key::num_1 },      { 0x1a, false, as2k_pc_key::z },
	{ 0x1b, false, as2k_pc_key::s },          { 0x1c, false, as2k_pc_key::a },
	{ 0x1d, false, as2k_pc_key::w },          { 0x1e, false, as2k_pc_key::num_2 },
	{ 0x21, false, as2k_pc_key::c },          { 0x22, false, as2k_pc_key::x },
	{ 0x23, false, as2k_pc_key::d },          { 0x24, false, as2k_pc_key::e },
	{ 0x25, false, as2k_pc_key::num_4 },      { 0x26, false, as2k_pc_key::num_3 },
	{ 0x29, false, as2k_pc_key::space },      { 0x2a, false, as2k_pc_key::v },
	{ 0x2b, false, as2k_pc_key::f },          { 0x2c, false, as2k_pc_key::t },
	{ 0x2d, false, as2k_pc_key::r },          { 0x2e, false, as2k_pc_key::num_5 },
	{ 0x31, false, as2k_pc_key::n },          { 0x32, false, as2k_pc_key::b },
	{ 0x33, false, as2k_pc_key::h },          { 0x34, false, as2k_pc_key::g },
	{ 0x35, false, as2k_pc_key::y },          { 0x36, false, as2k_pc_key::num_6 },
	{ 0x3a, false, as2k_pc_key::m },          { 0x3b, false, as2k_pc_key::j },
	{ 0x3c, false, as2k_pc_key::u },          { 0x3d, false, as2k_pc_key::num_7 },
	{ 0x3e, false, as2k_pc_key::num_8 },      { 0x41, false, as2k_pc_key::comma },
	{ 0x42, false, as2k_pc_key::k },          { 0x43, false, as2k_pc_key::i },
	{ 0x44, false, as2k_pc_key::o },          { 0x45, false, as2k_pc_key::num_0 },
	{ 0x46, false, as2k_pc_key::num_9 },      { 0x49, false, as2k_pc_key::period },
	{ 0x4a, false, as2k_pc_key::slash },      { 0x4b, false, as2k_pc_key::l },
	{ 0x4c, false, as2k_pc_key::semicolon },  { 0x4d, false, as2k_pc_key::p },
	{ 0x4e, false, as2k_pc_key::minus },      { 0x52, false, as2k_pc_key::quote },
	{ 0x54, false, as2k_pc_key::lbrace },     { 0x55, false, as2k_pc_key::equals },
	{ 0x58, false, as2k_pc_key::caps_lock },  { 0x59, false, as2k_pc_key::right_shift },
	{ 0x5a, false, as2k_pc_key::enter },      { 0x5b, false, as2k_pc_key::rbrace },
	{ 0x5d, false, as2k_pc_key::backslash },  { 0x66, false, as2k_pc_key::backspace },
	{ 0x69, false, as2k_pc_key::kp_1 },       { 0x6b, false, as2k_pc_key::kp_4 },
	{ 0x6c, false, as2k_pc_key::kp_7 },       { 0x70, false, as2k_pc_key::kp_0 },
	{ 0x72, false, as2k_pc_key::kp_2 },       { 0x73, false, as2k_pc_key::kp_5 },
	{ 0x74, false, as2k_pc_key::kp_6 },       { 0x75, false, as2k_pc_key::kp_8 },
	{ 0x7a, false, as2k_pc_key::kp_3 },       { 0x7d, false, as2k_pc_key::kp_9 }
};

// The host text layout is indexed by consecutive as2k_pc_key values from
// a through slash.  Each row is [unshifted, shifted]; Caps Lock applies
// only to the contiguous a..z range, not to punctuation or number keys.
// Alt-numeric composition is handled separately from this ordinary layout.
static constexpr char32_t s_pc_us_text[][2] =
{
	{ U'a', U'A' }, // a
	{ U'b', U'B' }, // b
	{ U'c', U'C' }, // c
	{ U'd', U'D' }, // d
	{ U'e', U'E' }, // e
	{ U'f', U'F' }, // f
	{ U'g', U'G' }, // g
	{ U'h', U'H' }, // h
	{ U'i', U'I' }, // i
	{ U'j', U'J' }, // j
	{ U'k', U'K' }, // k
	{ U'l', U'L' }, // l
	{ U'm', U'M' }, // m
	{ U'n', U'N' }, // n
	{ U'o', U'O' }, // o
	{ U'p', U'P' }, // p
	{ U'q', U'Q' }, // q
	{ U'r', U'R' }, // r
	{ U's', U'S' }, // s
	{ U't', U'T' }, // t
	{ U'u', U'U' }, // u
	{ U'v', U'V' }, // v
	{ U'w', U'W' }, // w
	{ U'x', U'X' }, // x
	{ U'y', U'Y' }, // y
	{ U'z', U'Z' }, // z
	{ U'0', U')' }, // num_0
	{ U'1', U'!' }, // num_1
	{ U'2', U'@' }, // num_2
	{ U'3', U'#' }, // num_3
	{ U'4', U'$' }, // num_4
	{ U'5', U'%' }, // num_5
	{ U'6', U'^' }, // num_6
	{ U'7', U'&' }, // num_7
	{ U'8', U'*' }, // num_8
	{ U'9', U'(' }, // num_9
	{ U'`', U'~' }, // grave
	{ U'-', U'_' }, // minus
	{ U'=', U'+' }, // equals
	{ U'[', U'{' }, // lbrace
	{ U']', U'}' }, // rbrace
	{ U'\\', U'|' }, // backslash
	{ U';', U':' }, // semicolon
	{ U'\'', U'"' }, // quote
	{ U',', U'<' }, // comma
	{ U'.', U'>' }, // period
	{ U'/', U'?' }, // slash
};

static_assert(std::size(s_pc_us_text) == unsigned(as2k_pc_key::slash) - unsigned(as2k_pc_key::a) + 1);

INPUT_CHANGED_MEMBER(asma2k_state::pc_connected_changed)
{
	// Once the standalone UI owns the PC-present state, the legacy Pause/Break
	// toggle remains a fallback input only and must not create a second source
	// of truth for the hardware-facing host-sense lines.
	if (m_ui_pc_override)
		return;

	// PC Connected defines the host session.  Send is intentionally not part
	// of the sink contract: a real PC only sees keyboard traffic on the wire.
	m_pc_frame = 0;
	m_pc_frame_bits = 0;
	pc_keyboard_reset();
	send_sink_end();
}

bool asma2k_state::pc_connected()
{
	return m_ui_pc_override ? m_ui_pc_connected : BIT(m_pc_connected->read(), 0);
}

void asma2k_state::pc_keyboard_reset()
{
	m_pc_set2_break = false;
	m_pc_set2_extended = false;
	m_pc_set2_e1_remaining = 0;
	m_pc_lshift = false;
	m_pc_rshift = false;
	m_pc_lctrl = false;
	m_pc_rctrl = false;
	m_pc_lalt = false;
	m_pc_ralt = false;
	m_pc_caps_lock = false;
	m_pc_alt_numeric_valid = false;
	m_pc_alt_numeric_count = 0;
}

void asma2k_state::pc_clock_rising(bool data)
{
	if (!m_pc_frame_bits)
	{
		if (data)
			return;
		m_pc_frame = 0;
	}

	if (data)
		m_pc_frame |= uint16_t(1) << m_pc_frame_bits;
	++m_pc_frame_bits;

	if (m_pc_frame_bits != 11)
		return;

	uint8_t const value = (m_pc_frame >> 1) & 0xff;
	bool odd_parity = BIT(m_pc_frame, 9);
	for (unsigned bit = 0; bit < 8; ++bit)
		odd_parity ^= BIT(value, bit);

	bool const valid = !BIT(m_pc_frame, 0) && BIT(m_pc_frame, 10) && odd_parity;
	bool const resync_start = !BIT(m_pc_frame, 10);
	m_pc_frame = 0;
	m_pc_frame_bits = 0;

	if (valid)
	{
		if (!m_send_sink_active)
		{
			if (!pc_connected())
				return;
			send_sink_begin();
			if (!m_send_sink_active)
				return;
		}

		pc_set2_byte(value);
	}
	else
	{
		logerror("AS2K_PC_FRAME_ERROR value=%02X\n", value);
		if (resync_start)
			m_pc_frame_bits = 1;
	}
}

void asma2k_state::asma2k_port_d_w(uint8_t data)
{
	bool const before = BIT(m_port_d, 0);
	bool const after = BIT(data, 0);

	// Printer capture reuses the previously validated physical PD0 waveform
	// decoder.  No firmware PC/routine hook is involved.
	if (m_ui_printer_connected && before != after)
	{
		uint64_t const tick = machine().time().as_ticks(2'000'000);
		if (!m_printer_frame_active && !before && after)
		{
			m_printer_frame_active = true;
			m_printer_start_tick = tick;
			m_printer_edge_count = 0;
			m_printer_frame_timer->adjust(attotime::from_ticks(330, 2'000'000));
		}
		if (m_printer_frame_active && m_printer_edge_count < m_printer_edge_ticks.size())
		{
			m_printer_edge_ticks[m_printer_edge_count] = tick;
			m_printer_edge_levels[m_printer_edge_count] = after;
			++m_printer_edge_count;
		}
	}
	else if (pc_connected() && !before && after)
	{
		pc_clock_rising(!BIT(data, 1)); // PC keyboard: PD0 clock, inverted PD1 data.
	}

	alphasmart_state::port_d_w(data);
}

TIMER_CALLBACK_MEMBER(asma2k_state::printer_frame_done)
{
	if (!m_printer_frame_active)
		return;

	m_printer_frame_active = false;
	if (!m_ui_printer_connected || !m_printer_edge_count)
		return;

	// Physical PD0 is inverted relative to the 8N1 byte.  These sample points
	// are the timings already established by the wired-printer regression.
	auto const level_at = [this](uint64_t tick) -> uint8_t
	{
		uint8_t level = 1;
		for (unsigned i = 0; i < m_printer_edge_count; ++i)
		{
			if (m_printer_edge_ticks[i] > tick)
				break;
			level = m_printer_edge_levels[i];
		}
		return level;
	};

	if (level_at(m_printer_start_tick + 328) != 0)
		return;

	uint8_t byte = 0;
	for (unsigned bit = 0; bit < 8; ++bit)
		byte |= !level_at(m_printer_start_tick + 48 + bit * 35) << bit;

	printer_capture_byte(byte);
}

void asma2k_state::printer_capture_byte(uint8_t byte)
{
	static constexpr unsigned max_job_bytes = 200'000;
	static constexpr std::array<uint8_t, 7> pcl_end =
		{ 0x1b, '&', 'l', '0', 'H', 0x1b, 'E' };

	if (!m_printer_capture)
	{
		std::string const output_directory(machine().options().snapshot_directory());
		std::string const filename =
			".as2k-print-pending-" + std::to_string(++m_printer_session_serial) + ".pcl";

		m_printer_capture = std::make_unique<emu_file>(
			output_directory,
			OPEN_FLAG_WRITE | OPEN_FLAG_CREATE | OPEN_FLAG_CREATE_PATHS);

		std::error_condition const err = m_printer_capture->open(filename);
		if (err)
		{
			logerror("AS2K_PRINT CAPTURE_OPEN_FAILED path=%s%s%s error=%s\n",
				output_directory, PATH_SEPARATOR, filename, err.message());
			m_printer_capture.reset();
			return;
		}

		m_printer_capture_bytes = 0;
		m_printer_tail_count = 0;
	}

	if (m_printer_capture_bytes >= max_job_bytes)
	{
		ui_emit_event("STATUS\tPrinter job rejected: capture exceeds 200000 bytes");
		printer_capture_end(false);
		return;
	}

	m_printer_capture->write(&byte, 1);
	++m_printer_capture_bytes;

	if (m_printer_tail_count < m_printer_tail.size())
	{
		m_printer_tail[m_printer_tail_count++] = byte;
	}
	else
	{
		for (unsigned i = 1; i < m_printer_tail.size(); ++i)
			m_printer_tail[i - 1] = m_printer_tail[i];
		m_printer_tail.back() = byte;
	}

	bool complete = m_printer_tail_count == pcl_end.size();
	for (unsigned i = 0; complete && i < pcl_end.size(); ++i)
		complete = m_printer_tail[i] == pcl_end[i];

	if (complete)
		printer_capture_end(true);
}

void asma2k_state::printer_capture_end(bool complete)
{
	std::string completed_path;
	if (m_printer_capture)
	{
		completed_path = m_printer_capture->fullpath();
		m_printer_capture->flush();
		m_printer_capture->close();
		m_printer_capture.reset();
	}

	unsigned const bytes = m_printer_capture_bytes;
	m_printer_capture_bytes = 0;
	m_printer_tail_count = 0;

	if (completed_path.empty())
		return;

	if (complete && bytes)
	{
		logerror("AS2K_PRINT JOB_COMPLETE bytes=%u path=%s\n", bytes, completed_path);
		ui_emit_event("PRINT_READY\t" + completed_path);
	}
	else
	{
		std::remove(completed_path.c_str());
	}
}

void asma2k_state::send_sink_begin()
{
	if (m_send_sink)
	{
		m_send_sink->close();
		m_send_sink.reset();
	}

	// Stable output follows MAME's configured output directory rather than
	// the firmware/DictROM source path.  The installed launcher points this
	// at the stable XDG data directory, keeping user output separate from
	// proprietary input images and from as2k-diag.
	std::string const output_directory(machine().options().snapshot_directory());
	std::string const filename = m_ui_event_path.empty()
			? "send.txt"
			: ".as2k-send-pending-" + std::to_string(++m_send_session_serial) + ".txt";

	m_send_sink = std::make_unique<emu_file>(
		output_directory,
		OPEN_FLAG_WRITE | OPEN_FLAG_CREATE | OPEN_FLAG_CREATE_PATHS);

	m_send_sink_had_data = false;
	std::error_condition const err = m_send_sink->open(filename);
	if (err)
	{
		logerror("AS2K_TX TEXT_SINK_OPEN_FAILED path=%s%s%s error=%s\n",
			output_directory,
			PATH_SEPARATOR,
			filename,
			err.message());
		m_send_sink.reset();
		m_send_sink_active = false;
	}
	else
	{
		logerror("AS2K_TX TEXT_SINK_OPEN path=%s\n", m_send_sink->fullpath());
		m_send_sink_active = true;
	}

}

void asma2k_state::pc_set2_byte(uint8_t data)
{
	if (m_pc_set2_e1_remaining)
	{
		--m_pc_set2_e1_remaining;
		return;
	}

	if (data == 0xe1)
	{
		// Pause/Break is the canonical eight-byte E1 sequence in Set 2.  It
		// carries no text, so consume the sequence without fabricating a key.
		m_pc_set2_e1_remaining = 7;
		m_pc_set2_break = false;
		m_pc_set2_extended = false;
		return;
	}

	if (data == 0xe0)
	{
		m_pc_set2_extended = true;
		return;
	}

	if (data == 0xf0)
	{
		m_pc_set2_break = true;
		return;
	}

	as2k_pc_key key = as2k_pc_key::none;
	for (auto const &entry : s_set2_keys)
	{
		if ((entry.code == data) && (entry.extended == m_pc_set2_extended))
		{
			key = entry.key;
			break;
		}
	}

	if (key != as2k_pc_key::none)
		pc_key_event(key, !m_pc_set2_break);
	else
		logerror("AS2K_PC_UNKNOWN_SET2 extended=%u break=%u code=%02X\n",
			m_pc_set2_extended ? 1U : 0U, m_pc_set2_break ? 1U : 0U, data);

	m_pc_set2_break = false;
	m_pc_set2_extended = false;
}

// Windows ANSI Alt+0xxx numeric codes use Windows-1252 for the
// 0x80-0x9f range. Undefined CP1252 byte positions have value zero.
// This is a selected host profile, NOT a claim about all receiving PCs.
static constexpr char32_t s_pc_windows_1252_extended[32] =
{
	U'€', 0, U'‚', U'ƒ', U'„', U'…', U'†', U'‡',
	U'ˆ', U'‰', U'Š', U'‹', U'Œ', 0, U'Ž', 0,
	0, U'‘', U'’', U'“', U'”', U'•', U'–', U'—',
	U'˜', U'™', U'š', U'›', U'œ', 0, U'ž', U'Ÿ'
};

void asma2k_state::pc_key_event(as2k_pc_key key, bool pressed)
{
	bool const was_alt = m_pc_lalt || m_pc_ralt;
	if (key == as2k_pc_key::left_alt || key == as2k_pc_key::right_alt)
	{
		if (key == as2k_pc_key::left_alt)
			m_pc_lalt = pressed;
		else
			m_pc_ralt = pressed;

		bool const now_alt = m_pc_lalt || m_pc_ralt;
		if (!was_alt && now_alt)
		{
			m_pc_alt_numeric_count = 0;
			m_pc_alt_numeric_valid = !(m_pc_lctrl || m_pc_rctrl || m_pc_lshift || m_pc_rshift);
		}
		else if (was_alt && !now_alt)
		{
			// Host Windows ANSI profile: Alt+0ddd is one composition.
			// Releasing Alt commits a complete, bounded keypad sequence only.
			if (m_pc_alt_numeric_valid && m_pc_alt_numeric_count == 4 && m_pc_alt_numeric_digits[0] == '0')
			{
				unsigned code = 0;
				for (char digit : m_pc_alt_numeric_digits)
					code = code * 10 + unsigned(digit - '0');

				char32_t character = 0;
				if (code >= 0x20 && code < 0x7f)
					character = char32_t(code);
				else if (code >= 0x80 && code < 0xa0)
					character = s_pc_windows_1252_extended[code - 0x80];
				else if (code >= 0xa0 && code <= 0xff)
					character = char32_t(code);

				if (character)
					send_sink_codepoint(character);
				else
					logerror("AS2K_PC_ALT_NUMERIC_UNMAPPED code=%u\n", code);
			}
			else if (m_pc_alt_numeric_count)
				logerror("AS2K_PC_ALT_NUMERIC_CANCEL count=%u\n", m_pc_alt_numeric_count);

			m_pc_alt_numeric_count = 0;
			m_pc_alt_numeric_valid = false;
		}
		return;
	}

	switch (key)
	{
	case as2k_pc_key::left_shift:  m_pc_lshift = pressed; break;
	case as2k_pc_key::right_shift: m_pc_rshift = pressed; break;
	case as2k_pc_key::left_ctrl:   m_pc_lctrl = pressed; break;
	case as2k_pc_key::right_ctrl:  m_pc_rctrl = pressed; break;
	case as2k_pc_key::caps_lock:
		if (pressed)
			m_pc_caps_lock = !m_pc_caps_lock;
		break;
	default:
		break;
	}

	// Any non-keypad press during Alt cancels the numeric transaction,
	// even if the pressed key is not normally a text key.
	if (pressed && was_alt)
	{
		char digit = 0;
		switch (key)
		{
		case as2k_pc_key::kp_0: digit = '0'; break;
		case as2k_pc_key::kp_1: digit = '1'; break;
		case as2k_pc_key::kp_2: digit = '2'; break;
		case as2k_pc_key::kp_3: digit = '3'; break;
		case as2k_pc_key::kp_4: digit = '4'; break;
		case as2k_pc_key::kp_5: digit = '5'; break;
		case as2k_pc_key::kp_6: digit = '6'; break;
		case as2k_pc_key::kp_7: digit = '7'; break;
		case as2k_pc_key::kp_8: digit = '8'; break;
		case as2k_pc_key::kp_9: digit = '9'; break;
		default: break;
		}
		if (digit && m_pc_alt_numeric_valid && m_pc_alt_numeric_count < 4)
			m_pc_alt_numeric_digits[m_pc_alt_numeric_count++] = digit;
		else
			m_pc_alt_numeric_valid = false;
		return;
	}

	if (!pressed)
		return;

	// Unrecognized combinations must not leak an ordinary printable key.
	if (m_pc_lctrl || m_pc_rctrl || was_alt)
	{
		logerror("AS2K_PC_COMPOSE_PENDING key=%u ctrl=%u alt=%u\n",
			unsigned(key), (m_pc_lctrl || m_pc_rctrl) ? 1U : 0U, was_alt ? 1U : 0U);
		return;
	}

	if (key == as2k_pc_key::left_shift || key == as2k_pc_key::right_shift ||
		key == as2k_pc_key::left_ctrl || key == as2k_pc_key::right_ctrl ||
		key == as2k_pc_key::caps_lock)
		return;

	if (key == as2k_pc_key::space)
	{
		send_sink_codepoint(U' ');
		return;
	}
	if (key == as2k_pc_key::tab)
	{
		send_sink_codepoint(U'\t');
		return;
	}
	if (key == as2k_pc_key::enter)
	{
		send_sink_codepoint(U'\n');
		return;
	}
	if (key == as2k_pc_key::backspace)
	{
		logerror("AS2K_PC_NON_TEXT backspace\n");
		return;
	}

	if (key >= as2k_pc_key::a && key <= as2k_pc_key::slash)
	{
		bool const shifted = m_pc_lshift || m_pc_rshift;
		bool const letter = key <= as2k_pc_key::z;
		bool const use_shifted = letter ? (shifted != m_pc_caps_lock) : shifted;
		send_sink_codepoint(s_pc_us_text[unsigned(key) - unsigned(as2k_pc_key::a)][use_shifted ? 1 : 0]);
		return;
	}

	logerror("AS2K_PC_NON_TEXT key=%u\n", unsigned(key));
}

void asma2k_state::send_sink_codepoint(char32_t codepoint)
{
	if (!m_send_sink_active)
		return;

	char utf8[4];
	size_t length = 0;
	if (codepoint <= 0x7f)
	{
		utf8[0] = char(codepoint);
		length = 1;
	}
	else if (codepoint <= 0x7ff)
	{
		utf8[0] = char(0xc0 | (codepoint >> 6));
		utf8[1] = char(0x80 | (codepoint & 0x3f));
		length = 2;
	}
	else if (codepoint <= 0xffff)
	{
		utf8[0] = char(0xe0 | (codepoint >> 12));
		utf8[1] = char(0x80 | ((codepoint >> 6) & 0x3f));
		utf8[2] = char(0x80 | (codepoint & 0x3f));
		length = 3;
	}
	else if (codepoint <= 0x10ffff)
	{
		utf8[0] = char(0xf0 | (codepoint >> 18));
		utf8[1] = char(0x80 | ((codepoint >> 12) & 0x3f));
		utf8[2] = char(0x80 | ((codepoint >> 6) & 0x3f));
		utf8[3] = char(0x80 | (codepoint & 0x3f));
		length = 4;
	}

	if (length)
	{
		m_send_sink->write(utf8, length);
		m_send_sink->flush();
		m_send_sink_had_data = true;
	}
}

void asma2k_state::send_sink_end()
{
	std::string completed_path;
	if (m_send_sink)
	{
		completed_path = m_send_sink->fullpath();
		m_send_sink->flush();
		m_send_sink->close();
		m_send_sink.reset();
	}
	m_send_sink_active = false;

	// In standalone-UI mode, the core never decides the user's destination.
	// It publishes the completed temporary capture only after the PC session
	// closes; the GTK front-end then presents Save As and removes the temporary
	// file.  Legacy non-UI execution preserves the historical send.txt sink.
	if (!m_ui_event_path.empty() && m_send_sink_had_data && !completed_path.empty())
		ui_emit_event("SEND_READY\t" + completed_path);

	m_send_sink_had_data = false;
}



void asma2k_state::ir_ui_flush()
{
	if (!m_ir_ui_batch_count || m_ir_session_kind.empty())
		return;

	static constexpr char hex[] = "0123456789ABCDEF";
	std::string payload;
	payload.reserve(size_t(m_ir_ui_batch_count) * 3);
	for (unsigned i = 0; i < m_ir_ui_batch_count; ++i)
	{
		if (i)
			payload.push_back(' ');
		uint8_t const value = m_ir_ui_batch[i];
		payload.push_back(hex[value >> 4]);
		payload.push_back(hex[value & 0x0f]);
	}

	ui_emit_event("IR_BYTES\t" + m_ir_session_kind + "\t" + payload);
	m_ir_ui_batch_count = 0;
}

void asma2k_state::ir_capture_begin(char const *kind)
{
	ir_capture_end(false);
	m_ir_capture_active = true;
	m_ir_frame_active = false;
	m_ir_escape = false;
	m_ir_session_bytes = 0;
	m_ir_frame_count = 0;
	m_ir_frame.clear();
	m_ir_ui_batch_count = 0;
	m_ir_session_kind = kind;
	ui_emit_event("STATUS\tIR " + m_ir_session_kind + " transmission started");
}

void asma2k_state::ir_capture_end(bool complete)
{
	if (!m_ir_capture_active)
		return;

	ir_ui_flush();
	if (complete)
		ui_emit_event("IR_DONE");
	m_ir_capture_active = false;
	m_ir_frame_active = false;
	m_ir_escape = false;
	m_ir_frame.clear();
	m_ir_ui_batch_count = 0;
	m_ir_session_kind.clear();
}

void asma2k_state::ir_frame_byte(uint8_t data)
{
	if (!m_ir_frame_active)
	{
		if (data == 0xc0)
		{
			m_ir_frame_active = true;
			m_ir_escape = false;
			m_ir_frame.clear();
		}
		return; // FF preamble/noise before C0 is still displayed by the UI.
	}

	if (m_ir_escape)
	{
		m_ir_frame.push_back(data ^ 0x20);
		m_ir_escape = false;
		return;
	}
	if (data == 0x7d)
	{
		m_ir_escape = true;
		return;
	}
	if (data == 0xc1)
	{
		++m_ir_frame_count;
		ir_peer_on_tx_frame(m_ir_frame);
		m_ir_frame_active = false;
		m_ir_escape = false;
		m_ir_frame.clear();
		return;
	}
	if (data == 0xc0)
	{
		m_ir_frame.clear();
		m_ir_escape = false;
		return;
	}
	m_ir_frame.push_back(data);
}

void asma2k_state::ir_tx_byte_w(uint8_t data)
{
	if (!m_ir_capture_active)
		return;

	++m_ir_session_bytes;
	m_ir_ui_batch[m_ir_ui_batch_count++] = data;
	if (m_ir_ui_batch_count == m_ir_ui_batch.size())
		ir_ui_flush();

	ir_frame_byte(data);
}

void asma2k_state::ir_event_w(uint8_t event)
{
	switch (event)
	{
	case 0x10:
		m_ir_peer_send_session = true;
		m_ir_peer_print_session = false;
		m_ir_peer_primary = true;
		ir_capture_begin("SEND");
		break;

	case 0x11:
		if (m_ir_peer_send_session)
		{
			m_ir_peer_send_session = false;
			ir_peer_stop();
			ir_capture_end(true);
		}
		break;

	case 0x20:
		m_ir_peer_print_session = true;
		m_ir_peer_send_session = false;
		m_ir_peer_primary = false;
		ir_capture_begin("PRINT");
		break;

	case 0x21:
		if (m_ir_peer_print_session)
		{
			m_ir_peer_print_session = false;
			ir_peer_stop();
			ir_capture_end(true);
		}
		break;

	case 0x30:
		if (m_ir_peer_send_session || m_ir_peer_print_session)
			ir_peer_begin();
		break;

	case 0x01:
		ir_ui_flush();
		if (m_ir_peer_pending && !m_ir_peer_active)
			m_ir_peer_timer->adjust(attotime::from_msec(2));
		break;

	default:
		break;
	}
}

static uint16_t as2k_ir_fcs16(std::vector<uint8_t> const &data)
{
	uint16_t fcs = 0xffff;
	for (uint8_t value : data)
	{
		fcs ^= value;
		for (unsigned bit = 0; bit < 8; ++bit)
			fcs = (fcs & 1) ? (fcs >> 1) ^ 0x8408 : fcs >> 1;
	}
	return fcs;
}

void asma2k_state::ir_peer_drive(bool high)
{
	m_ir_peer_level = high;
	m_maincpu->set_input_line(MC68HC11_PAI_LINE, high ? ASSERT_LINE : CLEAR_LINE);
}

void asma2k_state::ir_peer_stop()
{
	if (m_ir_peer_timer)
		m_ir_peer_timer->adjust(attotime::never);
	m_ir_peer_raw.clear();
	m_ir_peer_byte = 0;
	m_ir_peer_bit = 0;
	m_ir_peer_pulse_end = false;
	m_ir_peer_active = false;
	m_ir_peer_pending = 0;
	m_ir_peer_print_discovery_replied = false;
	m_ir_peer_file_receive = false;
	m_ir_print_complete = false;
	m_ir_peer_text_bytes = 0;
	m_ir_print_bytes = 0;
	m_ir_peer_stage = 0;
	m_ir_peer_xid_slot = 0;
	m_ir_peer_nr = 0;
	m_ir_peer_ns = 0;
	m_ir_peer_connection_address = 0x02;
	m_ir_peer_target = 0;
	ir_peer_drive(true);
}

void asma2k_state::ir_peer_begin()
{
	ir_peer_stop();
	m_ir_peer_stage = 1;
	m_ir_peer_xid_slot = 0;
	if (m_ir_peer_primary)
	{
		m_ir_peer_pending = 1;
		m_ir_peer_timer->adjust(attotime::from_msec(2));
	}
	// Print is the opposite IrLAP role.  Stock firmware performs discovery;
	// the peer waits passively for the first XID command.
}

void asma2k_state::ir_peer_send_frame(std::vector<uint8_t> const &body)
{
	if (m_ir_peer_active || body.empty())
		return;

	std::vector<uint8_t> framed(body);
	uint16_t const fcs = ~as2k_ir_fcs16(body);
	framed.push_back(uint8_t(fcs));
	framed.push_back(uint8_t(fcs >> 8));

	m_ir_peer_raw.assign(4, 0xff);
	m_ir_peer_raw.push_back(0xc0);
	for (uint8_t value : framed)
	{
		if (value == 0xc0 || value == 0xc1 || value == 0x7d)
		{
			m_ir_peer_raw.push_back(0x7d);
			m_ir_peer_raw.push_back(value ^ 0x20);
		}
		else
			m_ir_peer_raw.push_back(value);
	}
	m_ir_peer_raw.push_back(0xc1);

	m_ir_peer_byte = 0;
	m_ir_peer_bit = 0;
	m_ir_peer_pulse_end = false;
	m_ir_peer_active = true;
	ir_peer_drive(true);
	m_ir_peer_timer->adjust(attotime::zero);
}

void asma2k_state::ir_peer_send_xid()
{
	static constexpr uint8_t peer_address[4] = { 0x11, 0x22, 0x33, 0x44 };
	std::vector<uint8_t> body = { 0xff, 0x3f, 0x01 };
	body.insert(body.end(), std::begin(peer_address), std::end(peer_address));
	body.insert(body.end(), { 0xff, 0xff, 0xff, 0xff });
	uint8_t const slot = m_ir_peer_xid_slot;
	body.push_back(slot == 0 ? 0x05 : 0x01);
	body.push_back(slot < 6 ? slot : 0xff);
	body.push_back(0x00);
	if (slot >= 6)
	{
		static constexpr uint8_t info[] =
			{ 0x82, 0x04, 0x00, 'M', 'A', 'M', 'E', ' ', 'I', 'r', 'D', 'A' };
		body.insert(body.end(), std::begin(info), std::end(info));
	}
	ir_peer_send_frame(body);
}

void asma2k_state::ir_peer_send_xid_response()
{
	if (!m_ir_peer_target)
		return;

	static constexpr uint8_t peer_address[4] = { 0x11, 0x22, 0x33, 0x44 };
	std::vector<uint8_t> body = { 0xfe, 0xbf, 0x01 };
	body.insert(body.end(), std::begin(peer_address), std::end(peer_address));
	body.push_back(uint8_t(m_ir_peer_target >> 24));
	body.push_back(uint8_t(m_ir_peer_target >> 16));
	body.push_back(uint8_t(m_ir_peer_target >> 8));
	body.push_back(uint8_t(m_ir_peer_target));
	body.push_back(0x01);
	body.push_back(m_ir_peer_xid_slot);
	body.push_back(0x00);
	static constexpr uint8_t info[] =
		{ 0x88, 0x00, 0x00, 'M', 'A', 'M', 'E', ' ', 'P', 'r', 'i', 'n', 't', 'e', 'r' };
	body.insert(body.end(), std::begin(info), std::end(info));
	ir_peer_send_frame(body);
}

void asma2k_state::ir_peer_send_snrm()
{
	if (!m_ir_peer_target)
		return;

	static constexpr uint8_t peer_address[4] = { 0x11, 0x22, 0x33, 0x44 };
	std::vector<uint8_t> body = { 0xff, 0x93 };
	body.insert(body.end(), std::begin(peer_address), std::end(peer_address));
	body.push_back(uint8_t(m_ir_peer_target >> 24));
	body.push_back(uint8_t(m_ir_peer_target >> 16));
	body.push_back(uint8_t(m_ir_peer_target >> 8));
	body.push_back(uint8_t(m_ir_peer_target));
	body.push_back(0x02);
	static constexpr uint8_t params[] =
	{
		0x01,0x01,0x02, 0x82,0x01,0x01, 0x83,0x01,0x01, 0x84,0x01,0x01,
		0x85,0x01,0x10, 0x86,0x01,0x01, 0x08,0x01,0x01
	};
	body.insert(body.end(), std::begin(params), std::end(params));
	m_ir_peer_stage = 3;
	ir_peer_send_frame(body);
}

void asma2k_state::ir_peer_send_ua()
{
	if (!m_ir_peer_target)
		return;

	static constexpr uint8_t peer_address[4] = { 0x11, 0x22, 0x33, 0x44 };
	std::vector<uint8_t> body = { m_ir_peer_connection_address, 0x73 };
	body.insert(body.end(), std::begin(peer_address), std::end(peer_address));
	body.push_back(uint8_t(m_ir_peer_target >> 24));
	body.push_back(uint8_t(m_ir_peer_target >> 16));
	body.push_back(uint8_t(m_ir_peer_target >> 8));
	body.push_back(uint8_t(m_ir_peer_target));
	static constexpr uint8_t params[] =
	{
		0x01,0x01,0x02, 0x82,0x01,0x01, 0x83,0x01,0x01, 0x84,0x01,0x01,
		0x85,0x01,0x01, 0x86,0x01,0x0a, 0x08,0x01,0x01
	};
	body.insert(body.end(), std::begin(params), std::end(params));
	m_ir_peer_stage = 4;
	m_ir_peer_nr = 0;
	m_ir_peer_ns = 0;
	ir_peer_send_frame(body);
}

void asma2k_state::ir_peer_send_rr(uint8_t nr, bool final_bit)
{
	uint8_t const control = uint8_t(0x01 | ((nr & 7) << 5) | (final_bit ? 0x10 : 0x00));
	std::vector<uint8_t> body =
		{ uint8_t(m_ir_peer_primary ? (m_ir_peer_connection_address | 0x01) : m_ir_peer_connection_address), control };
	ir_peer_send_frame(body);
}

void asma2k_state::ir_peer_send_i(std::vector<uint8_t> const &info)
{
	uint8_t const control = uint8_t(((m_ir_peer_ns & 7) << 1) | 0x10 | ((m_ir_peer_nr & 7) << 5));
	std::vector<uint8_t> body =
		{ uint8_t(m_ir_peer_primary ? (m_ir_peer_connection_address | 0x01) : m_ir_peer_connection_address), control };
	body.insert(body.end(), info.begin(), info.end());
	m_ir_peer_ns = (m_ir_peer_ns + 1) & 7;
	ir_peer_send_frame(body);
}

void asma2k_state::ir_peer_on_tx_frame(std::vector<uint8_t> const &frame)
{
	if ((!m_ir_peer_send_session && !m_ir_peer_print_session) || frame.size() < 4)
		return;

	uint8_t const control = frame[1];

	if (m_ir_peer_print_session && !m_ir_peer_primary && control == 0x3f && frame.size() >= 16)
	{
		m_ir_peer_target = (uint32_t(frame[3]) << 24) | (uint32_t(frame[4]) << 16) |
			(uint32_t(frame[5]) << 8) | frame[6];
		uint8_t const slot = frame[12];
		if (!m_ir_peer_print_discovery_replied && slot == 1)
		{
			m_ir_peer_xid_slot = slot;
			m_ir_peer_print_discovery_replied = true;
			m_ir_peer_pending = 10;
		}
		return;
	}

	if (m_ir_peer_print_session && !m_ir_peer_primary && control == 0x93 && frame.size() >= 13)
	{
		m_ir_peer_target = (uint32_t(frame[2]) << 24) | (uint32_t(frame[3]) << 16) |
			(uint32_t(frame[4]) << 8) | frame[5];
		m_ir_peer_connection_address = frame[10] & 0xfe;
		m_ir_peer_stage = 3;
		m_ir_peer_pending = 11;
		return;
	}

	if (control == 0xbf && frame.size() >= 9)
	{
		m_ir_peer_target = (uint32_t(frame[3]) << 24) | (uint32_t(frame[4]) << 16) |
			(uint32_t(frame[5]) << 8) | frame[6];
	}
	else if (m_ir_peer_primary && control == 0x73)
	{
		m_ir_peer_stage = 4;
		m_ir_peer_nr = 0;
		m_ir_peer_pending = 3;
	}
	else if (!(control & 0x01) && m_ir_peer_stage >= 4)
	{
		uint8_t const incoming_ns = (control >> 1) & 7;
		if (incoming_ns != m_ir_peer_nr)
		{
			m_ir_peer_pending = 3;
			return;
		}
		m_ir_peer_nr = (m_ir_peer_nr + 1) & 7;

		bool const lm_connect_ias =
			frame.size() >= 8 && frame[2] == 0x80 && frame[3] == 0x52 && frame[4] == 0x01;
		bool const ias_query =
			frame.size() >= 10 && frame[2] == 0x00 && frame[3] == 0x52 && frame[4] == 0x84;
		bool const lm_connect_service =
			frame.size() >= 9 && frame[2] == 0x91 && frame[3] == 0x53 && frame[4] == 0x01;
		bool const lm_connect_irlpt =
			m_ir_peer_print_session && frame.size() >= 8 &&
			frame[2] == 0x91 && frame[3] == 0x51 && frame[4] == 0x01;
		bool const irlpt_data =
			m_ir_peer_print_session && frame.size() >= 6 &&
			frame[2] == 0x11 && frame[3] == 0x51;
		bool const irlpt_disconnect =
			m_ir_peer_print_session && frame.size() >= 8 &&
			frame[2] == 0x91 && frame[3] == 0x51 && frame[4] == 0x02;

		if (irlpt_data)
			m_ir_print_bytes += unsigned(frame.size() - 6);

		static constexpr uint8_t app_greeting_bytes[] =
			{ 'A','l','p','h','a','S','m','a','r','t',' ','I','R',' ','v','1','.','0' };
		bool app_greeting =
			m_ir_peer_send_session && !m_ir_peer_file_receive &&
			frame.size() == 26 && frame[2] == 0x11 && frame[3] == 0x53 &&
			frame[4] <= 0x7f && frame[5] == 0x00;
		if (app_greeting)
			for (unsigned i = 0; i < std::size(app_greeting_bytes); ++i)
				app_greeting &= frame[6 + i] == app_greeting_bytes[i];

		bool const app_send_ready =
			m_ir_peer_send_session && frame.size() >= 9 &&
			frame[2] == 0x11 && frame[3] == 0x53 && frame[5] == 0x00 && frame[6] == 0xfb;
		bool const app_file_data =
			m_ir_peer_file_receive && frame.size() >= 8 &&
			frame[2] == 0x11 && frame[3] == 0x53 && frame[5] == 0x00;
		bool const app_send_eof =
			m_ir_peer_file_receive && frame.size() == 7 &&
			frame[2] == 0x11 && frame[3] == 0x53;

		if (app_send_ready && !m_ir_peer_file_receive)
		{
			m_ir_peer_file_receive = true;
			m_ir_peer_text_bytes = 0;
		}

		if (app_file_data)
			m_ir_peer_text_bytes += unsigned(frame.size() - 8);

		if (app_send_eof)
			m_ir_peer_file_receive = false;

		if (lm_connect_ias)
			m_ir_peer_pending = 4;
		else if (ias_query)
			m_ir_peer_pending = 5;
		else if (lm_connect_service)
			m_ir_peer_pending = 6;
		else if (lm_connect_irlpt)
			m_ir_peer_pending = 12;
		else if (app_greeting)
			m_ir_peer_pending = 7;
		else if (app_send_eof)
			m_ir_peer_pending = 9;
		else if (app_send_ready || app_file_data)
			m_ir_peer_pending = 8;
		else
			m_ir_peer_pending = 3;

		(void)irlpt_disconnect; // Link teardown is completed by the LAP DISC below.
	}
	else if (m_ir_peer_print_session && !m_ir_peer_primary && control == 0x53 && m_ir_peer_stage >= 4)
	{
		m_ir_peer_pending = 13;
	}
	else if ((control & 0x03) == 0x01 && m_ir_peer_stage >= 4 && BIT(control, 4))
	{
		m_ir_peer_pending = 3;
	}
}

TIMER_CALLBACK_MEMBER(asma2k_state::ir_peer_timer)
{
	static constexpr uint64_t bit_ticks = 210;
	static constexpr uint64_t pulse_ticks = 36;

	if (!m_ui_ir_enabled || (!m_ir_peer_send_session && !m_ir_peer_print_session))
	{
		ir_peer_stop();
		return;
	}

	if (!m_ir_peer_active)
	{
		// PA6 gates the external I/O window.  Delay the optical peer while
		// stock firmware has that window selected for its own transmit cycle.
		if (m_ir_peer_pending && !BIT(m_port_a, 6))
		{
			m_ir_peer_timer->adjust(attotime::from_ticks(bit_ticks, 2'000'000));
			return;
		}

		uint8_t const pending = m_ir_peer_pending;
		m_ir_peer_pending = 0;
		switch (pending)
		{
		case 1: ir_peer_send_xid(); return;
		case 2: ir_peer_send_snrm(); return;
		case 3: ir_peer_send_rr(m_ir_peer_nr, true); return;
		case 4: ir_peer_send_i({ 0xd2, 0x00, 0x81, 0x00 }); return;
		case 5:
			ir_peer_send_i({ 0x52, 0x00, 0x84, 0x00, 0x00, 0x01, 0x00, 0x01,
				0x01, 0x00, 0x00, 0x00, 0x11 });
			return;
		case 6: ir_peer_send_i({ 0xd3, 0x11, 0x81, 0x00, 0x05 }); return;
		case 7: ir_peer_send_i({ 0x53, 0x11, 0x05, 0x00, 0xbc, 0x84 }); return;
		case 8: ir_peer_send_i({ 0x53, 0x11, 0x05, 0x00 }); return;
		case 9: ir_peer_send_i({ 0x53, 0x11, 0x05, 0x00, 0xbc, 0x92 }); return;
		case 10: ir_peer_send_xid_response(); return;
		case 11: ir_peer_send_ua(); return;
		case 12: ir_peer_send_i({ 0xd1, 0x11, 0x81, 0x00 }); return;
		case 13:
			m_ir_print_complete = true;
			ir_peer_send_frame({ m_ir_peer_connection_address, 0x73 });
			return;
		default: return;
		}
	}

	if (m_ir_peer_pulse_end)
	{
		ir_peer_drive(true);
		m_ir_peer_pulse_end = false;
		++m_ir_peer_bit;
		if (m_ir_peer_bit >= 10)
		{
			m_ir_peer_bit = 0;
			++m_ir_peer_byte;
		}
		m_ir_peer_timer->adjust(attotime::from_ticks(bit_ticks - pulse_ticks, 2'000'000));
		return;
	}

	if (m_ir_peer_byte >= m_ir_peer_raw.size())
	{
		m_ir_peer_active = false;
		ir_peer_drive(true);
		if (m_ir_peer_primary && m_ir_peer_stage == 1)
		{
			if (m_ir_peer_xid_slot < 6)
			{
				++m_ir_peer_xid_slot;
				m_ir_peer_pending = 1;
				m_ir_peer_timer->adjust(attotime::from_msec(12));
			}
			else
			{
				m_ir_peer_stage = 2;
				m_ir_peer_pending = 2;
				m_ir_peer_timer->adjust(attotime::from_msec(15));
			}
		}
		return;
	}

	uint8_t const value = m_ir_peer_raw[m_ir_peer_byte];
	bool const pulse =
		(m_ir_peer_bit == 0) ||
		(m_ir_peer_bit >= 1 && m_ir_peer_bit <= 8 && !BIT(value, m_ir_peer_bit - 1));

	if (pulse)
	{
		ir_peer_drive(false);
		m_ir_peer_pulse_end = true;
		m_ir_peer_timer->adjust(attotime::from_ticks(pulse_ticks, 2'000'000));
	}
	else
	{
		++m_ir_peer_bit;
		if (m_ir_peer_bit >= 10)
		{
			m_ir_peer_bit = 0;
			++m_ir_peer_byte;
		}
		m_ir_peer_timer->adjust(attotime::from_ticks(bit_ticks, 2'000'000));
	}
}

void asma2k_state::ui_emit_event(std::string const &line)
{
	if (m_ui_event_path.empty())
		return;

	std::ofstream output(m_ui_event_path, std::ios::out | std::ios::app);
	if (!output)
	{
		logerror("AS2K_UI EVENT_OPEN_FAILED path=%s\n", m_ui_event_path);
		return;
	}

	output << line << '\n';
	output.flush();
}

void asma2k_state::ui_bridge_init()
{
	if (char const *path = std::getenv("AS2K_UI_CONTROL_FILE"))
		m_ui_control_path = path;
	if (char const *path = std::getenv("AS2K_UI_EVENT_FILE"))
		m_ui_event_path = path;
	if (char const *path = std::getenv("AS2K_UI_FRAME_FILE"))
		m_ui_frame_path = path;

	m_ui_key_release_timer = timer_alloc(FUNC(asma2k_state::ui_key_release), this);

	if (!m_ui_control_path.empty())
	{
		m_ui_bridge_timer = timer_alloc(FUNC(asma2k_state::ui_bridge_tick), this);
		m_ui_bridge_timer->adjust(attotime::from_msec(10), 0, attotime::from_msec(10));
		ui_emit_event("STATUS\tAS2K core/UI bridge ready");
	}
}

TIMER_CALLBACK_MEMBER(asma2k_state::ui_bridge_tick)
{
	ui_bridge_poll();
}

TIMER_CALLBACK_MEMBER(asma2k_state::ui_key_release)
{
	if (m_ui_key_col < 0)
		return;

	m_ui_keyboard[m_ui_key_col] |= m_ui_key_mask;
	m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE);
	m_ui_key_col = -1;
	m_ui_key_mask = 0;
}

void asma2k_state::ui_bridge_poll()
{
	if (m_ui_control_path.empty())
		return;

	std::ifstream input(m_ui_control_path, std::ios::in | std::ios::binary);
	if (!input)
		return;

	input.seekg(0, std::ios::end);
	std::streamoff const size = input.tellg();
	if (size < 0)
		return;
	if (size < m_ui_control_offset)
		m_ui_control_offset = 0;
	if (size == m_ui_control_offset)
		return;

	input.seekg(m_ui_control_offset, std::ios::beg);
	std::string chunk(
		(std::istreambuf_iterator<char>(input)),
		std::istreambuf_iterator<char>());
	m_ui_control_offset = size;

	std::istringstream lines(chunk);
	std::string line;
	while (std::getline(lines, line))
	{
		if (!line.empty() && line.back() == '\r')
			line.pop_back();
		if (!line.empty())
			ui_process_command(line);
	}
}

bool asma2k_state::ui_press_key(std::string_view name)
{
	struct key_map
	{
		std::string_view name;
		uint8_t col;
		uint8_t mask;
	};

	// These are the AlphaSmart 2000 matrix locations already used by the
	// physical keyboard ports below.  The UI overlay therefore enters exactly
	// the same kb_r/IRQ path; it never calls a firmware routine directly.
	static constexpr key_map keys[] =
	{
		{ "ESC",   4,  0x80 },
		{ "F1",   11,  0x10 },
		{ "F2",   10,  0x10 },
		{ "F3",   10,  0x01 },
		{ "F4",   10,  0x02 },
		{ "F5",    9,  0x02 },
		{ "F6",    0,  0x02 },
		{ "F7",    2,  0x01 },
		{ "F8",    2,  0x10 },
		{ "PRINT", 9,  0x10 },
		{ "SPELL", 9,  0x20 },
		{ "FIND",  7,  0x40 },
		{ "CLEAR", 4,  0x20 },
		{ "HOME",  4,  0x08 },
		{ "END",   5,  0x40 },
		{ "ENTER", 6,  0x10 },
		{ "SEND",  7,  0x10 },
	};

	for (auto const &entry : keys)
	{
		if (entry.name != name)
			continue;

		if (m_ui_key_col >= 0)
			m_ui_keyboard[m_ui_key_col] |= m_ui_key_mask;

		m_ui_key_col = entry.col;
		m_ui_key_mask = entry.mask;
		m_ui_keyboard[entry.col] &= ~entry.mask;
		m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE);
		m_ui_key_release_timer->adjust(attotime::from_msec(45));
		return true;
	}

	return false;
}

void asma2k_state::ui_process_command(std::string const &line)
{
	if (line.rfind("KEY ", 0) == 0)
	{
		std::string_view const key(line.data() + 4, line.size() - 4);
		if (!ui_press_key(key))
			ui_emit_event("STATUS\tUnsupported virtual key: " + std::string(key));
		return;
	}

	if (line == "PC ON" || line == "PC OFF")
	{
		bool const connected = line == "PC ON";
		bool const changed = !m_ui_pc_override || (connected != m_ui_pc_connected);
		m_ui_pc_override = true;
		m_ui_pc_connected = connected;
		if (changed)
		{
			m_pc_frame = 0;
			m_pc_frame_bits = 0;
			pc_keyboard_reset();
			send_sink_end();
		}
		ui_emit_event(std::string("STATUS\tPC ") + (connected ? "connected" : "disconnected"));
		return;
	}

	if (line == "PRINTER ON" || line == "PRINTER OFF")
	{
		bool const connected = line == "PRINTER ON";
		if (!connected)
		{
			m_printer_frame_active = false;
			m_printer_frame_timer->adjust(attotime::never);
			printer_capture_end(false);
		}
		m_ui_printer_connected = connected;
		ui_emit_event(std::string("STATUS\tPrinter ") + (connected ? "connected" : "disconnected"));
		return;
	}

	if (line == "IR ON" || line == "IR OFF")
	{
		bool const enabled = line == "IR ON";
		if (!enabled)
		{
			ir_capture_end(false);
			m_ir_peer_send_session = false;
			m_ir_peer_print_session = false;
			ir_peer_stop();
		}
		m_ui_ir_enabled = enabled;
		m_maincpu->set_input_line(MC68HC11_PAI_LINE, ASSERT_LINE);
		ui_emit_event(std::string("STATUS\tIR ") + (enabled ? "ready" : "disabled"));
		return;
	}

	if (line == "MACHINE RESET")
	{
		machine().schedule_soft_reset();
		ui_emit_event("STATUS\tSoft reset requested");
		return;
	}

	if (line == "KEY POWER" || line == "MACHINE POWER")
	{
		ui_emit_event("STATUS\tPower-key emulation pending hardware contract");
		return;
	}

	if (line.rfind("FIRMWARE ", 0) == 0 || line.rfind("DICTROM ", 0) == 0 ||
		line.rfind("PAYLOAD ", 0) == 0 || line.rfind("PAYLOAD_FILE ", 0) == 0)
	{
		ui_emit_event("STATUS\tImage/payload selection recorded by UI; restart/load bridge pending");
		return;
	}

	ui_emit_event("STATUS\tUnknown UI command: " + line);
}

void asma2k_state::ui_write_frame(bitmap_ind16 const &bitmap)
{
	if (m_ui_frame_path.empty())
		return;

	constexpr unsigned width = 6 * 40;
	constexpr unsigned height = 9 * 4;
	std::array<uint8_t, width * height> frame{};

	for (unsigned y = 0; y < height; ++y)
		for (unsigned x = 0; x < width; ++x)
			frame[y * width + x] = bitmap.pix(y, x) ? 1 : 0;

	std::ofstream output(m_ui_frame_path, std::ios::out | std::ios::binary | std::ios::trunc);
	if (output)
		output.write(reinterpret_cast<char const *>(frame.data()), frame.size());
}

void asma2k_state::screen_updated(bitmap_ind16 const &bitmap)
{
	ui_write_frame(bitmap);
}

void asma2k_state::port_a_w(uint8_t data)
{
	m_io_view.select(BIT(data, 6));

	m_rambank->set_entry(((data>>4) & 0x03));
	m_dict_bank = ((data & 0x30) >> 3) | ((m_lcd_ctrl & 0x80) >> 7);
	m_port_a = data;
}


void asma2k_state::asma2k_mem(address_map &map)
{
	map.unmap_value_high();
	map(0x0000, 0x7fff).view(m_io_view);
	m_io_view[0](0x2000, 0x2000).rw(FUNC(asma2k_state::kb_r), FUNC(asma2k_state::kb_matrixh_w));
	m_io_view[0](0x4000, 0x4000).w(FUNC(asma2k_state::lcd_ctrl_w));
	m_io_view[0](0x4000, 0x7fff).r(FUNC(asma2k_state::dictrom_r));
	m_io_view[1](0x0000, 0x7fff).bankrw("rambank");
	map(0x8000, 0xffff).r(FUNC(asma2k_state::firmware_r));
	map(0x9000, 0x9000).w(FUNC(asma2k_state::kb_matrixl_w));
}

DEVICE_IMAGE_LOAD_MEMBER(asma2k_state::firmware_load)
{
	auto &slot = downcast<generic_slot_device &>(image.device());
	uint32_t const source_size = slot.common_get_size("rom");

	// Known ZPSD dumps contain either the 32 KiB executable image alone or
	// the executable image followed by mapper/PAL data.  Stable emulation
	// consumes only the executable 0x8000-byte window and leaves the source
	// file untouched.
	if (source_size != 0x8000 && source_size != 0x81e5)
		return std::make_pair(
				image_error::INVALIDLENGTH,
				"Unsupported AS2K firmware image size (expected 0x8000 or 0x81e5 bytes)");

	if (!slot.get_rom_base())
		slot.rom_alloc(0x8000, GENERIC_ROM8_WIDTH, ENDIANNESS_BIG);

	if (slot.get_rom_size() != 0x8000)
		return std::make_pair(image_error::INVALIDLENGTH, "Internal firmware socket size mismatch");

	slot.common_load_rom(slot.get_rom_base(), 0x8000, "rom");
	return std::make_pair(std::error_condition(), std::string());
}

DEVICE_IMAGE_LOAD_MEMBER(asma2k_state::dictrom_load)
{
	auto &slot = downcast<generic_slot_device &>(image.device());
	uint32_t const source_size = slot.common_get_size("rom");

	if (source_size != 0x20000)
		return std::make_pair(
				image_error::INVALIDLENGTH,
				"Unsupported AS2K DictROM image size (expected 0x20000 bytes)");

	if (!slot.get_rom_base())
		slot.rom_alloc(0x20000, GENERIC_ROM8_WIDTH, ENDIANNESS_BIG);

	if (slot.get_rom_size() != 0x20000)
		return std::make_pair(image_error::INVALIDLENGTH, "Internal DictROM socket size mismatch");

	slot.common_load_rom(slot.get_rom_base(), 0x20000, "rom");
	return std::make_pair(std::error_condition(), std::string());
}

uint8_t asma2k_state::firmware_r(offs_t offset)
{
	return m_firmware->get_rom_base() ? m_firmware->read_rom(offset & 0x7fff) : 0xff;
}

uint8_t asma2k_state::dictrom_r(offs_t offset)
{
	return m_dictrom->get_rom_base()
			? m_dictrom->read_rom((uint32_t(m_dict_bank) << 14) | (offset & 0x3fff))
			: 0xff;
}


bool asma2k_state::set_cpu_state(char const *symbol, uint64_t value)
{
	for (auto const &entry : m_maincpu->state_entries())
	{
		if (!strcmp(entry->symbol(), symbol))
		{
			m_maincpu->set_state_int(entry->index(), value);
			return true;
		}
	}

	return false;
}

void asma2k_state::apply_direct_dictrom_bootstrap()
{
	// Stable Direct DictROM Bootstrap models the machine state after the
	// ATtiny/HC11 bootstrap stage-0 has completed.  It intentionally does not
	// emulate the SCI download or temporary HPRIO special-mode transition.
	//
	// The independently authored stage-0 contract is:
	//   SEI; LDS #$00C3; CONFIG|=$04; MDA=1;
	//   PORTA&=~$70; CTRL=$04; clear RBOOT/SMOD; JMP $4000.
	//
	// Apply bus/device state first and PC last.  This is therefore not an
	// arbitrary PC jump: every observable post-bootstrap precondition modeled
	// by the stable emulator is established before DictROM executes.
	port_a_w(0x00);
	lcd_ctrl_w(0x04);

	bool ok = true;
	ok &= set_cpu_state("SP", 0x00c3);
	ok &= set_cpu_state("CCR", 0x00d0); // S|X|I remain set
	ok &= set_cpu_state("A", 0x0004);
	ok &= set_cpu_state("B", 0x0000);
	ok &= set_cpu_state("IX", 0x0000);
	ok &= set_cpu_state("IY", 0x0000);
	ok &= set_cpu_state("CONFIG", 0x0004);

	if (!ok)
		fatalerror("AS2K stable Direct DictROM Bootstrap: HC11 state contract unavailable");

	// Entry is committed only after all other preconditions have succeeded.
	if (!set_cpu_state("PC", 0x4000))
		fatalerror("AS2K stable Direct DictROM Bootstrap: PC state unavailable");

	logerror("AS2K stable Direct DictROM Bootstrap: PC=4000 SP=00C3 CCR=D0 A=04 PA=00 CTRL=04 bank=0\n");
}


/* Input ports */
static INPUT_PORTS_START( asma2k )
	PORT_START("COL.0")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_CLOSEBRACE) PORT_CHAR(']') PORT_CHAR('}') PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F6)   PORT_CHAR(UCHAR_MAMEKEY(F6)) PORT_NAME("F6 (File 6)") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_K)     PORT_CHAR('k') PORT_CHAR('K')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_I)     PORT_CHAR('i') PORT_CHAR('I')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_EQUALS) PORT_CHAR('=') PORT_CHAR('+') PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_8)     PORT_CHAR('8') PORT_CHAR('*')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_COMMA) PORT_CHAR(',') PORT_CHAR('<')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_START("COL.1")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_LALT) PORT_NAME("Left Alt/Option") PORT_CHAR(UCHAR_MAMEKEY(LALT))   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_RCONTROL) PORT_NAME("Right Alt/Option") PORT_CHAR(UCHAR_MAMEKEY(RALT))   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_START("COL.2")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F7)   PORT_CHAR(UCHAR_MAMEKEY(F7)) PORT_NAME("F7 (File 7)") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_L)     PORT_CHAR('l') PORT_CHAR('L')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_O)     PORT_CHAR('o') PORT_CHAR('O')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F8)   PORT_CHAR(UCHAR_MAMEKEY(F8)) PORT_NAME("F8 (File 8)") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_9)     PORT_CHAR('9') PORT_CHAR('(')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_STOP)  PORT_CHAR('.') PORT_CHAR('>')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_START("COL.3")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_OPENBRACE) PORT_CHAR('[') PORT_CHAR('{')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_QUOTE) PORT_CHAR('\'')    PORT_CHAR('\"') PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_COLON) PORT_CHAR(';') PORT_CHAR(':')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_P)     PORT_CHAR('p') PORT_CHAR('P')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_MINUS) PORT_CHAR('-') PORT_CHAR('_')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_0)     PORT_CHAR('0') PORT_CHAR(')')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_SLASH) PORT_CHAR('/') PORT_CHAR('?')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_START("COL.4")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_LWIN) PORT_CODE(KEYCODE_PGUP)  PORT_NAME("Command") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_HOME) PORT_CHAR(UCHAR_MAMEKEY(HOME))   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_DEL)  PORT_CHAR(UCHAR_MAMEKEY(NUMLOCK)) PORT_NAME("Clear File") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_RALT) PORT_CHAR(UCHAR_MAMEKEY(ESC))    PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_START("COL.5")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_DOWN) PORT_CHAR(UCHAR_MAMEKEY(DOWN))   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_END)  PORT_CHAR(UCHAR_MAMEKEY(END))    PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_LEFT) PORT_CHAR(UCHAR_MAMEKEY(LEFT))   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_START("COL.6")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_ENTER_PAD) PORT_NAME("Enter") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_RIGHT) PORT_CHAR(UCHAR_MAMEKEY(RIGHT)) PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_START("COL.7")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F12) PORT_NAME("Send") PORT_CHAR(UCHAR_MAMEKEY(F12)) PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F11)  PORT_CHAR(UCHAR_MAMEKEY(F11)) PORT_NAME("Find") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_UP)   PORT_CHAR(UCHAR_MAMEKEY(UP))     PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_START("COL.8")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_START("COL.9")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_BACKSPACE) PORT_NAME("Delete") PORT_CHAR(UCHAR_MAMEKEY(BACKSPACE)) PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F5)   PORT_CHAR(UCHAR_MAMEKEY(F5)) PORT_NAME("F5 (File 5)") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_BACKSLASH) PORT_CHAR('\\') PORT_CHAR('|') PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F9)   PORT_CHAR(UCHAR_MAMEKEY(F9)) PORT_NAME("Print") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F10)  PORT_CHAR(UCHAR_MAMEKEY(F10)) PORT_NAME("Spell Check") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_ENTER)   PORT_NAME("Return") PORT_CHAR(13) PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_SPACE)     PORT_CHAR(' ') PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_START("COL.10")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F3)   PORT_CHAR(UCHAR_MAMEKEY(F3)) PORT_NAME("F3 (File 3)") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F4)   PORT_CHAR(UCHAR_MAMEKEY(F4)) PORT_NAME("F4 (File 4)") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_D)    PORT_CHAR('d')  PORT_CHAR('D')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_E)    PORT_CHAR('e')  PORT_CHAR('E')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F2)   PORT_CHAR(UCHAR_MAMEKEY(F2)) PORT_NAME("F2 (File 2)") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_3)    PORT_CHAR('3')  PORT_CHAR('#')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_C)    PORT_CHAR('c')  PORT_CHAR('C')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_START("COL.11")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_CAPSLOCK) PORT_CHAR(UCHAR_MAMEKEY(CAPSLOCK)) PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_S)    PORT_CHAR('s')  PORT_CHAR('S')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_W)    PORT_CHAR('w')  PORT_CHAR('W')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F1)   PORT_CHAR(UCHAR_MAMEKEY(F1)) PORT_NAME("F1 (File 1)") PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_2)    PORT_CHAR('2')  PORT_CHAR('@')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_X)    PORT_CHAR('x')  PORT_CHAR('X')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_START("COL.12")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_TAB)  PORT_CHAR('\t')   PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_A)    PORT_CHAR('a')  PORT_CHAR('A')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_Q)    PORT_CHAR('q')  PORT_CHAR('Q')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_TILDE) PORT_CHAR('`') PORT_CHAR('~')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_1)    PORT_CHAR('1')  PORT_CHAR('!')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_Z)    PORT_CHAR('z')  PORT_CHAR('Z')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_LCONTROL) PORT_CHAR(UCHAR_MAMEKEY(LCONTROL)) PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_START("COL.13")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_T)    PORT_CHAR('t')  PORT_CHAR('T')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_G)    PORT_CHAR('g')  PORT_CHAR('G')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_F)    PORT_CHAR('f')  PORT_CHAR('F')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_R)    PORT_CHAR('r')  PORT_CHAR('R')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_5)    PORT_CHAR('5')  PORT_CHAR('%')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_4)    PORT_CHAR('4')  PORT_CHAR('$')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_V)    PORT_CHAR('v')  PORT_CHAR('V')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_B)    PORT_CHAR('b')  PORT_CHAR('B')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_START("COL.14")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_LSHIFT) PORT_CHAR(UCHAR_SHIFT_1) PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_RSHIFT) PORT_CHAR(UCHAR_MAMEKEY(RSHIFT)) PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_UNUSED)
	PORT_START("COL.15")
	PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_Y)    PORT_CHAR('y')  PORT_CHAR('Y')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x02, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_H)    PORT_CHAR('h')  PORT_CHAR('H')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x04, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_J)    PORT_CHAR('j')  PORT_CHAR('J')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x08, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_U)    PORT_CHAR('u')  PORT_CHAR('U')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x10, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_6)    PORT_CHAR('6')  PORT_CHAR('^')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x20, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_7)    PORT_CHAR('7')  PORT_CHAR('&')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x40, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_M)    PORT_CHAR('m')  PORT_CHAR('M')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)
	PORT_BIT(0x80, IP_ACTIVE_LOW, IPT_KEYBOARD) PORT_CODE(KEYCODE_N)    PORT_CHAR('n')  PORT_CHAR('N')  PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(alphasmart_state::kb_irq), 0)

	// Emulator-only host attachment control.  Pause/Break is not part of the
	// AlphaSmart 2000 keyboard matrix, so it cannot be mistaken for an AS2K key.
	PORT_START("PC_CONNECTED")
	PORT_BIT(0x01, IP_ACTIVE_HIGH, IPT_OTHER) PORT_NAME("PC Connected (Pause/Break)") PORT_CODE(KEYCODE_PAUSE) PORT_TOGGLE PORT_CHANGED_MEMBER(DEVICE_SELF, FUNC(asma2k_state::pc_connected_changed), 0)

	PORT_START("BOOT_MODE")
	PORT_CONFNAME(0x01, 0x00, "Startup mode")
	PORT_CONFSETTING(0x00, "Normal firmware boot")
	PORT_CONFSETTING(0x01, "Direct DictROM bootstrap")

	PORT_START("BATTERY")
	PORT_CONFNAME(0x01, 0x01, "Battery status")
	PORT_CONFSETTING (0x00, DEF_STR(Low))
	PORT_CONFSETTING (0x01, DEF_STR(Normal))
INPUT_PORTS_END

void alphasmart_state::alphasmart_palette(palette_device &palette) const
{
	palette.set_pen_color(0, rgb_t(138, 146, 148));
	palette.set_pen_color(1, rgb_t(92, 83, 88));
}

uint32_t alphasmart_state::screen_update(screen_device &screen, bitmap_ind16 &bitmap, const rectangle &cliprect)
{
	m_lcdc[0]->screen_update(screen, *m_tmp_bitmap, cliprect);
	copybitmap(bitmap, *m_tmp_bitmap, 0, 0, 0, 0, cliprect);
	m_lcdc[1]->screen_update(screen, *m_tmp_bitmap, cliprect);
	copybitmap(bitmap, *m_tmp_bitmap, 0, 0, 0, 18,cliprect);
	screen_updated(bitmap);
	return 0;
}

void alphasmart_state::machine_start()
{
	m_rambank->configure_entries(0, 4, &m_nvram_base[0], 0x8000);

	m_tmp_bitmap = std::make_unique<bitmap_ind16>(6 * 40, 9 * 4);
}

void asma2k_state::machine_start()
{
	alphasmart_state::machine_start();

	save_item(NAME(m_lcd_ctrl));
	save_item(NAME(m_dict_bank));
	save_item(NAME(m_printer_frame_active));
	save_item(NAME(m_printer_edge_count));
	save_item(NAME(m_printer_start_tick));
	save_item(NAME(m_printer_edge_ticks));
	save_item(NAME(m_printer_edge_levels));
	m_printer_frame_timer = timer_alloc(FUNC(asma2k_state::printer_frame_done), this);
	m_ir_peer_timer = timer_alloc(FUNC(asma2k_state::ir_peer_timer), this);
	ui_bridge_init();
}

void asma2k_state::machine_reset()
{
	alphasmart_state::machine_reset();

	m_lcd_ctrl = 0;
	m_dict_bank = 0;
	m_io_view.select(0);
	m_printer_frame_active = false;
	if (m_printer_frame_timer)
		m_printer_frame_timer->adjust(attotime::never);
	printer_capture_end(false);
	m_ir_peer_send_session = false;
	m_ir_peer_print_session = false;
	ir_capture_end(false);
	ir_peer_stop();
	m_maincpu->set_input_line(MC68HC11_PAI_LINE, ASSERT_LINE);

	if (BIT(m_boot_mode->read(), 0))
		apply_direct_dictrom_bootstrap();
}

void alphasmart_state::machine_reset()
{
	m_rambank->set_entry(0);
	m_matrix[0] = m_matrix[1] = 0;
	m_ui_keyboard.fill(0xff);
	m_port_a = 0;
	m_port_d = 0;
}

void alphasmart_state::alphasmart(machine_config &config)
{
	/* basic machine hardware */
	MC68HC11D0(config, m_maincpu, 8_MHz_XTAL);
	m_maincpu->set_addrmap(AS_PROGRAM, &alphasmart_state::alphasmart_mem);
	m_maincpu->in_pa_callback().set(FUNC(alphasmart_state::port_a_r));
	m_maincpu->out_pa_callback().set(FUNC(alphasmart_state::port_a_w));
	m_maincpu->in_pd_callback().set(FUNC(alphasmart_state::port_d_r));
	m_maincpu->out_pd_callback().set(FUNC(alphasmart_state::port_d_w));

	for (auto &lcdc : m_lcdc)
	{
		KS0066(config, lcdc, 270'000); // TODO: clock not measured, datasheet typical clock used
		lcdc->set_default_bios_tag("f05");
		lcdc->set_lcd_size(2, 40);
	}

	/* video hardware */
	screen_device &screen(SCREEN(config, "screen").set_lcd());
	screen.set_refresh_hz(50);
	screen.set_vblank_time(ATTOSECONDS_IN_USEC(2500)); /* not accurate */
	screen.set_screen_update(FUNC(alphasmart_state::screen_update));
	screen.set_size(6*40, 9*4);
	screen.set_visarea_full();
	screen.set_palette("palette");

	PALETTE(config, "palette", FUNC(alphasmart_state::alphasmart_palette), 2);

	NVRAM(config, "nvram", nvram_device::DEFAULT_ALL_0);
}

void asma2k_state::asma2k(machine_config &config)
{
	alphasmart(config);
	m_maincpu->in_pa_callback().set(FUNC(asma2k_state::asma2k_port_a_r));
	m_maincpu->out_pd_callback().set(FUNC(asma2k_state::asma2k_port_d_w));
	m_maincpu->as2k_ir_tx_callback().set(FUNC(asma2k_state::ir_tx_byte_w));
	m_maincpu->as2k_ir_event_callback().set(FUNC(asma2k_state::ir_event_w));
	m_maincpu->set_addrmap(AS_PROGRAM, &asma2k_state::asma2k_mem);

	// External user-supplied images.  These devices are intentionally not
	// tied to MAME ROM-set filenames or checksums.  Mounting an image uses
	// the normal MAME image/file UI and resets the machine.
	GENERIC_SOCKET(config, m_firmware, generic_plain_slot, "as2k_firmware", "bin,rom,zpsd");
	m_firmware->set_device_load(FUNC(asma2k_state::firmware_load));
	m_firmware->set_must_be_loaded(true);

	GENERIC_SOCKET(config, m_dictrom, generic_plain_slot, "as2k_dictrom", "bin,rom");
	m_dictrom->set_device_load(FUNC(asma2k_state::dictrom_load));
	m_dictrom->set_must_be_loaded(true);
}

// AS2K-only reduced target: AlphaSmart Pro ROM registration intentionally omitted.


// MCU: MC68HC11D0FN
// NVRAM: NEC D431000ACW-70LL + battery
// XTAL: SB8.000
// LCD: 2x KS0066F05 + 4x KS0063B
// Optional IrDA sub board
ROM_START( asma2k )
ROM_END

} // anonymous namespace


//    YEAR  NAME     PARENT  COMPAT  MACHINE     INPUT       CLASS             INIT        COMPANY                           FULLNAME           FLAGS
COMP( 1997, asma2k,  0,      0,      asma2k,     asma2k,     asma2k_state,     empty_init, "Intelligent Peripheral Devices", "AlphaSmart 2000", MACHINE_NOT_WORKING | MACHINE_NO_SOUND )
