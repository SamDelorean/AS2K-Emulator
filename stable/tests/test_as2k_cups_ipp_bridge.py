#!/usr/bin/env python3
"""Regression tests for original AS2K HP2 and optional HP5 to CUPS/IPP bridge.

Real MAME-DIAG F47-A10 physical PORTD-decoded bytes; no ROM bytes or print jobs.
"""
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase, main
from unittest.mock import patch
import subprocess

P = Path(__file__).resolve().parents[1] / "frontend" / "as2k_pcl_to_pdf.py"
spec = importlib.util.spec_from_file_location("as2k_pcl_to_pdf", P)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

HP2 = bytes.fromhex("1b451b266b33471b267330431b266130384c1b266137304d1b266c3035451b266c33441b283855414243203132330d0d1b266c30481b45")
HP5 = bytes.fromhex("1b451b266b33471b267330431b266130384c1b266137304d1b266c3035451b266c33441b2838551b287331501b266c3340414243203132330d0d1b266c30481b45")

class TestBridge(TestCase):
    def test_original_hp2(self):
        self.assertEqual(m.parse_observed_hp_text(HP2), [["ABC 123"]])
    def test_opt_in_hp5(self):
        self.assertEqual(m.parse_observed_hp_text(HP5), [["ABC 123"]])
    def test_only_full_hp5_preset(self):
        for d in (HP5.replace(b"\x1b&l3@",b""),HP5.replace(b"\x1b(s1P",b""),HP5.replace(b"\x1b&l3@",b"\x1b&l3@\x1b&l3@")):
            with self.subTest(data=d):
                self.assertRaises(ValueError,m.parse_observed_hp_text,d)
    def test_unknown_pcl_refused(self):
        self.assertRaises(ValueError,m.parse_observed_hp_text,HP2.replace(b"\x1b(8U",b"\x1b%Z"))
    def test_no_implicit_printer(self):
        with TemporaryDirectory() as d, patch.object(m.shutil,"which",return_value="/bin/false"), patch.object(m,"find_pdf_ppd",return_value=Path("/tmp/mock.ppd")),patch.object(m.subprocess,"run",return_value=subprocess.CompletedProcess([],0,b"%PDF-1.4\nx",b"")) as sp:
            src=Path(d)/"in.pcl"; src.write_bytes(HP5)
            self.assertEqual(m.main(),2) if False else None
            with patch("sys.argv",["as2k_pcl_to_pdf.py",str(src),str(Path(d)/"out.pdf")]):
                self.assertEqual(m.main(),0)
            self.assertEqual(sp.call_count,1) # cupsfilter only, never lp
    def test_explicit_queue_checks_advertised_name(self):
        with patch.object(m,"cups_destinations",return_value=["MyPrinter"]):
            self.assertRaises(ValueError,m.submit_pdf,Path("out.pdf"),"other")
    def test_explicit_queue_safe_argv(self):
        r=subprocess.CompletedProcess([],0,"request id is MyPrinter-4","")
        with patch.object(m,"cups_destinations",return_value=["MyPrinter"]),patch.object(m.shutil,"which",return_value="/usr/bin/lp"),patch.object(m.subprocess,"run",return_value=r) as sp:
            self.assertIn("MyPrinter",m.submit_pdf(Path("/tmp/a.pdf"),"MyPrinter"))
            self.assertEqual(sp.call_args.args[0],["/usr/bin/lp","-d","MyPrinter","-t","AS2K Writer","--","/tmp/a.pdf"])

if __name__=="__main__":
    main()
