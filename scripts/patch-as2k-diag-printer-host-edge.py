#!/usr/bin/env python3
"""Add only the wired-printer PA0/host-edge IRQ to the already-PC-patched AS2K-DIAG.

Fail closed: verify canonical HEAD and the exact SHA of the known-good DIAG
driver; preserve all other changes and back up the original before replacing.
Never run on AS2K Stable, ASPRO, or the MAME reference source.
"""
from pathlib import Path
import argparse
import hashlib
import os
import subprocess
import sys

EXPECTED_HEAD = "a4b99b1a700a1d70b93a798fe7833e4cae28c137"
EXPECTED_SHA256 = "cb2e63129a3f7f647b55a22e27caef55a78f57c5086563968015ce49923cfdb4"
MARKER = "AS2K_DIAG_PRINTER_HOST_EDGE_WAKE_IRQ"

def change(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise ValueError(f"{label}: expected one exact anchor, found {count}")
    return text.replace(old, new, 1)

def patch(text: str) -> str:
    if MARKER in text or "PRINTER_CONNECTED" in text:
        raise ValueError("printer patch or port already exists")
    text = change(
        text,
        ', m_diag_pc(*this, "PC_CONNECTED")',
        ', m_diag_pc(*this, "PC_CONNECTED")\n\t\t, m_diag_printer(*this, "PRINTER_CONNECTED")',
        "constructor printer port")
    text = change(
        text,
        "    required_ioport m_diag_pc;\n    bool m_diag_pc_last = false;",
        "    required_ioport m_diag_pc;\n    required_ioport m_diag_printer;\n"
        "    bool m_diag_pc_last = false;\n    bool m_diag_printer_last = false;\n"
        "    void diag_printer_sync();",
        "printer members and sync declaration")
    text = change(
        text,
        "    if (BIT(m_diag_pc->read(), 0))\n        data |= 0x05;",
        "    // Stable wiring: printer-ready PA0 takes priority; PC uses PA0+PA2.\n"
        "    if (BIT(m_diag_printer->read(), 0))\n        data |= 0x01;\n"
        "    else if (BIT(m_diag_pc->read(), 0))\n        data |= 0x05;",
        "host-sense wiring")
    before = """TIMER_CALLBACK_MEMBER(asma2k_state::diag_pc_tick)
{
    diag_pc_sync();
}"""
    after = """void asma2k_state::diag_printer_sync()
{
    bool const connected = BIT(m_diag_printer->read(), 0);
    if (connected == m_diag_printer_last)
        return;
    m_diag_printer_last = connected;
    // Mirror Stable's printer readiness notification. Do not inject Print,
    // touch the physical PC Send decoder or fake a PCL/PDF transaction.
    m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE);
    uint8_t const host = diag_pc_port_a_r();
    logerror("AS2K_DIAG_PRINTER_HOST_EDGE_WAKE_IRQ attached=%u pa0=%u pa2=%u\\n",
        connected ? 1U : 0U, unsigned(BIT(host, 0)), unsigned(BIT(host, 2)));
}

TIMER_CALLBACK_MEMBER(asma2k_state::diag_pc_tick)
{
    diag_pc_sync();
    diag_printer_sync();
}"""
    text = change(text, before, after, "single 10ms host timer")
    text = change(text,
        "    m_diag_pc_last = false;\n    save_item(NAME(m_diag_pc_last));",
        "    m_diag_pc_last = false;\n    m_diag_printer_last = false;\n"
        "    save_item(NAME(m_diag_pc_last));\n"
        "    save_item(NAME(m_diag_printer_last));",
        "startup initialized LOW, no input reads in machine_start")
    text = change(text,
        '\tPORT_START("PC_CONNECTED")\n'
        '\tPORT_BIT(0x01, IP_ACTIVE_HIGH, IPT_OTHER) PORT_NAME("DIAG PC cable attached (external input)")',
        '\tPORT_START("PC_CONNECTED")\n'
        '\tPORT_BIT(0x01, IP_ACTIVE_HIGH, IPT_OTHER) PORT_NAME("DIAG PC cable attached (external input)")\n'
        '\tPORT_START("PRINTER_CONNECTED")\n'
        '\tPORT_BIT(0x01, IP_ACTIVE_HIGH, IPT_OTHER) PORT_NAME("DIAG wired printer attached (external input)")',
        "printer DIAG input")
    assert text.count(MARKER) == 1
    assert text.count("AS2K_DIAG_PC_HOST_EDGE_WAKE_IRQ") == 1
    return text

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--driver",type=Path,required=True)
    p.add_argument("--backup",type=Path,required=True)
    args=p.parse_args()
    path=args.driver.absolute()
    if path.is_symlink() or not path.is_file():
        raise ValueError("DIAG driver must be a real file")
    root=path.parents[3]
    if path.relative_to(root).as_posix() != "src/mame/skeleton/alphasma.cpp":
        raise ValueError("wrong DIAG driver path")
    head=subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],text=True).strip()
    if head != EXPECTED_HEAD:
        raise ValueError("unexpected canonical MAME-DIAG HEAD")
    original=path.read_bytes()
    got=hashlib.sha256(original).hexdigest()
    if got!=EXPECTED_SHA256:
        raise ValueError("unexpected DIAG driver SHA: "+got)
    backup=args.backup.absolute()
    if backup.exists() or backup.is_symlink():
        raise ValueError("backup already exists")
    revised=patch(original.decode("utf-8")).encode("utf-8")
    backup.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    backup.write_bytes(original)
    tmp=path.with_name(path.name+".pc-printer-increment.tmp")
    if tmp.exists() or tmp.is_symlink():
        raise ValueError("patch temporary file already exists")
    try:
        tmp.write_bytes(revised)
        os.chmod(tmp,path.stat().st_mode & 0o777)
        os.replace(tmp,path)
    finally:
        if tmp.exists():
            tmp.unlink()
    print("AS2K_DIAG_PRINTER_PATCHED",got,hashlib.sha256(revised).hexdigest())
    print("AS2K_DIAG_PC_IRQ_PRESERVED; PRINTER_IRQ_ADDED; NO_GENERIC_MAME")
if __name__=="__main__":
    try:
        main()
    except (OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("BLOCKED_AS2K_DIAG_PRINTER_PATCH:",str(e),file=sys.stderr)
        sys.exit(4)
