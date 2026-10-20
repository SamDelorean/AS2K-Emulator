#!/usr/bin/env python3
"""Apply only PC-host sense and HC11 host-edge IRQ to the canonical AS2K-DIAG driver.

Fail closed on source drift; unrelated working-tree changes are never reset.
MAME-DIAG has no GTK bridge, so a DIAG-only PC_CONNECTED input is introduced.
"""
from pathlib import Path
import argparse, hashlib, os, sys

MARK = "AS2K_DIAG_PC_HOST_EDGE_WAKE_IRQ"

def replace_one(src, before, after, label):
    if src.count(before) != 1:
        raise ValueError(f"{label}: expected exactly one source anchor, found {src.count(before)}")
    return src.replace(before, after, 1)

def patch(src):
    if MARK in src:
        raise ValueError("DIAG host-edge patch already present; do not apply twice")
    src = replace_one(src,
       ', m_dictbank(*this, "dictbank")',
       ', m_dictbank(*this, "dictbank")\n\t\t, m_diag_pc(*this, "PC_CONNECTED")', "constructor IO port")
    name="class asma2k_state : public alphasmart_state"
    beg=src.index(name)
    end=src.index("\n};",beg)
    block=src[beg:end]
    block += """
    // DIAG-only experimental host cable; no GTK bridge or Set2 sink here.
    uint8_t diag_pc_port_a_r();
    void diag_pc_sync();
    TIMER_CALLBACK_MEMBER(diag_pc_tick);
    required_ioport m_diag_pc;
    bool m_diag_pc_last = false;
"""
    src=src[:beg]+block+src[end:]
    before="INPUT_CHANGED_MEMBER(alphasmart_state::kb_irq)"
    extra=r"""uint8_t asma2k_state::diag_pc_port_a_r()
{
    uint8_t data = alphasmart_state::port_a_r();
    // Same wired host sense as the proven AS2K stable transport: PA0+PA2.
    data &= ~uint8_t(0x05);
    if (BIT(m_diag_pc->read(), 0))
        data |= 0x05;
    return data;
}

void asma2k_state::diag_pc_sync()
{
    bool const connected = BIT(m_diag_pc->read(), 0);
    if (connected == m_diag_pc_last)
        return;
    m_diag_pc_last = connected;
    // Notify sleeping stock firmware exactly once per host transition;
    // no phantom matrix key, no Send decoding and no MAME stable UI.
    m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE);
    logerror("AS2K_DIAG_PC_HOST_EDGE_WAKE_IRQ attached=%u\n", connected ? 1U : 0U);
}

TIMER_CALLBACK_MEMBER(asma2k_state::diag_pc_tick)
{
    diag_pc_sync();
}

"""
    src=replace_one(src,before,extra+before,"handler")
    before="void asma2k_state::machine_start()\n{\n\talphasmart_state::machine_start();"
    after=before+"""
    m_diag_pc_last = BIT(m_diag_pc->read(), 0);
    save_item(NAME(m_diag_pc_last));
    timer_alloc(FUNC(asma2k_state::diag_pc_tick), this)->adjust(
        attotime::from_msec(10), 0, attotime::from_msec(10));"""
    src=replace_one(src,before,after,"periodic observer")
    before="void asma2k_state::asma2k(machine_config &config)\n{\n\talphasmart(config);"
    after=before+"""
    // Bind host-present PA0/PA2 on DIAG only, not on Pro or AS2K-Stable.
    m_maincpu->in_pa_callback().set(FUNC(asma2k_state::diag_pc_port_a_r));"""
    src=replace_one(src,before,after,"PA callback")
    before="static INPUT_PORTS_START( asma2k )"
    start=src.index(before)
    finish=src.index("INPUT_PORTS_END",start)
    if 'PORT_START("PC_CONNECTED")' in src[start:finish]:
        raise ValueError("DIAG PC_CONNECTED already exists")
    insertion="""\tPORT_START("PC_CONNECTED")
\tPORT_BIT(0x01, IP_ACTIVE_HIGH, IPT_OTHER) PORT_NAME("DIAG PC cable attached (external input)")
"""
    src=src[:finish]+insertion+src[finish:]
    assert src.count(MARK)==1
    return src

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path",type=Path)
    parser.add_argument("--expected-head",required=True)
    parser.add_argument("--backup",type=Path,required=True)
    args=parser.parse_args()
    p=args.path.resolve(strict=True)
    root=p.parents[3] # .../src/mame/skeleton/alphasma.cpp -> MAME checkout root
    if str(p.relative_to(root))!="src/mame/skeleton/alphasma.cpp":
        raise ValueError("wrong MAME driver path")
    import subprocess
    head=subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],text=True).strip()
    if head!=args.expected_head:
        raise ValueError("unexpected DIAG HEAD; do not patch")
    status=subprocess.check_output(["git","-C",str(root),"status","--porcelain","--",str(p)],text=True)
    if status.strip():
        raise ValueError("DIAG driver already modified; refuse overwrite")
    old=p.read_bytes()
    new=patch(old.decode("utf-8")).encode("utf-8")
    backup=args.backup.resolve()
    backup.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    if backup.exists(): raise ValueError("backup already exists")
    backup.write_bytes(old)
    tmp=p.with_name(p.name+".as2k-diag-hostedge.tmp")
    if tmp.exists(): raise ValueError("temporary driver already exists")
    tmp.write_bytes(new)
    os.replace(tmp,p)
    print("AS2K_DIAG_HOSTEDGE_PATCHED",hashlib.sha256(old).hexdigest(),hashlib.sha256(new).hexdigest(),flush=True)
    return 0

if __name__=="__main__":
    try: raise SystemExit(main())
    except (OSError,ValueError,AssertionError) as exc:
        print("BLOCKED_AS2K_DIAG_PATCH:",str(exc),file=sys.stderr)
        raise SystemExit(4)
