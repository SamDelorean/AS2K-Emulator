#!/usr/bin/env python3
"""Convert the verified AS2000 HP/PCL-text subset to PDF through CUPS filters."""
from __future__ import annotations

import pathlib
import shutil
import subprocess
import sys

PCL_COMMANDS = (
    b"\x1b&k3G", b"\x1b&s0C", b"\x1b&a08L", b"\x1b&a70M",
    b"\x1b&l05E", b"\x1b&l3D", b"\x1b&l0H", b"\x1b(8U", b"\x1bE",
)
MAX_JOB = 200_000


def parse_observed_hp_text(raw: bytes) -> list[list[str]]:
    if not raw.startswith(b"\x1bE\x1b&k3G"):
        raise ValueError("Not the verified HP/PCL-text profile")
    if not raw.endswith(b"\x1b&l0H\x1bE"):
        raise ValueError("Incomplete HP/PCL-text job")

    pages: list[list[str]] = [[]]
    line: list[str] = []
    cr_to_lf = False
    saw_text = False
    saw_reset = False
    i = 0

    def end_line() -> None:
        if line:
            pages[-1].append("".join(line))
            line.clear()

    while i < len(raw):
        if raw[i] == 0x1B:
            cmd = next((c for c in PCL_COMMANDS if raw.startswith(c, i)), None)
            if cmd is None:
                raise ValueError(f"Unsupported PCL escape at offset {i}")
            if cmd == b"\x1b&k3G":
                cr_to_lf = True
            if cmd == b"\x1bE":
                saw_reset = True
            if cmd == b"\x1b&l0H":
                end_line()
            i += len(cmd)
            continue

        value = raw[i]
        i += 1
        if 0x20 <= value <= 0x7E:
            line.append(chr(value))
            saw_text = True
        elif value == 0x09:
            line.extend(" " * (8 - len(line) % 8))
        elif value == 0x0D:
            if cr_to_lf:
                end_line()
            else:
                line.clear()
        elif value == 0x0A:
            end_line()
        elif value == 0x0C:
            end_line()
            if pages[-1]:
                pages.append([])
        else:
            raise ValueError(f"Unsupported PCL byte 0x{value:02x} at {i-1}")

        if len(line) > 120 or sum(map(len, pages[-1])) > 3000:
            raise ValueError("Printer job exceeds verified text layout bounds")

    end_line()
    pages = [page for page in pages if page]
    if not saw_text or not saw_reset or not pages:
        raise ValueError("No complete printable HP/PCL-text content")
    return pages


def find_pdf_ppd() -> pathlib.Path:
    candidates = [
        pathlib.Path("/usr/share/ppd/cupsfilters/Generic-PDF_Printer-PDF.ppd"),
        pathlib.Path("/usr/share/ppd/cupsfilters/Ricoh-PDF_Printer-PDF.ppd"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    for pattern in (
        "/usr/share/ppd/**/*PDF*.ppd",
        "/usr/share/ghostscript/*/lib/ghostpdf.ppd",
    ):
        matches = sorted(pathlib.Path("/").glob(pattern.lstrip("/")))
        if matches:
            return matches[0]
    raise RuntimeError("No generic PDF PPD found; install cups-filters")


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: as2k_pcl_to_pdf.py INPUT.pcl OUTPUT.pdf", file=sys.stderr)
        return 2

    source = pathlib.Path(sys.argv[1])
    target = pathlib.Path(sys.argv[2])
    if not source.is_file() or source.stat().st_size > MAX_JOB:
        raise ValueError("Missing or oversized printer job")

    pages = parse_observed_hp_text(source.read_bytes())
    payload = "\f".join("\n".join(lines) + "\n" for lines in pages).encode("ascii")
    cupsfilter = shutil.which("cupsfilter")
    if not cupsfilter:
        raise RuntimeError("cupsfilter is not installed")
    ppd = find_pdf_ppd()

    result = subprocess.run(
        [cupsfilter, "-i", "text/plain", "-m", "application/pdf", "-p", str(ppd)],
        input=payload, capture_output=True, timeout=20, check=False,
    )
    if result.returncode:
        detail = result.stderr.decode("utf-8", "replace").strip()[-1200:]
        raise RuntimeError(f"CUPS PDF conversion failed: {detail}")
    if not result.stdout.startswith(b"%PDF-"):
        raise RuntimeError("CUPS did not return a PDF document")

    target.parent.mkdir(parents=True, exist_ok=True)
    staged = target.with_name("." + target.name + ".as2k-staged")
    try:
        staged.write_bytes(result.stdout)
        staged.replace(target)
    finally:
        staged.unlink(missing_ok=True)

    print(f"AS2K_CUPS_PDF_PASS pages={len(pages)} bytes={len(result.stdout)} output={target}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, UnicodeError, subprocess.TimeoutExpired) as exc:
        print(f"AS2K_CUPS_PDF_REJECTED: {exc}", file=sys.stderr)
        raise SystemExit(2)
