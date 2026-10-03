# AS2K stable implementation status

Date: 2026-10-02  
Branch: `feature/as2k-stable-ui-r1` (based on `prep/as2k-stable-reduced-r0`)

This table distinguishes source prepared statically from behavior proven by native execution.

| Component | Source status | Native/runtime status |
|---|---|---|
| AS2K-only registration | PREPARED | PENDING reduced binary |
| External Firmware socket | PREPARED | PENDING UI load bridge |
| External DictROM socket | PREPARED | PENDING UI load bridge |
| No fixed proprietary ROM-set dependency | STATIC PASS | PENDING full runtime |
| Normal firmware boot | PRESERVED BY DESIGN | PENDING full runtime |
| Direct DictROM bootstrap | PREPARED | PENDING full runtime |
| LCD 40x4 core | DONOR/SHARED | DRIVER COMPILE PASS |
| Standalone AS2K GTK UI shell | IMPLEMENTED | Python static gate PASS; live Surface test PENDING |
| LCD mirror core→UI | IMPLEMENTED | DRIVER COMPILE PASS; runtime acceptance PENDING |
| Mouse special keys→matrix | IMPLEMENTED | DRIVER COMPILE PASS; runtime acceptance PENDING |
| 100/150/200/fullscreen UI | IMPLEMENTED | live GUI test PENDING |
| PNG LCD screenshot | IMPLEMENTED | live GUI test PENDING |
| MP4/H.264 LCD recording, no audio | IMPLEMENTED | FFmpeg/live GUI test PENDING |
| Ayuda→Atajos de teclado | IMPLEMENTED | static gate PASS; live GUI test PENDING |
| Workbench payload selector | UI IMPLEMENTED | core payload/load bridge PENDING |
| Keyboard/F1-F8/sleep-wake | DONOR/SHARED | DRIVER COMPILE PASS |
| 128 KiB NVRAM/banking | DONOR + external DictROM refactor | DRIVER COMPILE PASS |
| PC host-present state from UI | IMPLEMENTED through existing PA host-sense path | DRIVER COMPILE PASS; runtime acceptance PENDING |
| PC Send physical-port decoding | VALIDATED DONOR + UI session integration | DRIVER COMPILE PASS; runtime acceptance PENDING |
| Send Save-As-on-disconnect | IMPLEMENTED core event + GTK Save As | runtime acceptance PENDING |
| IR hexadecimal display UI | IMPLEMENTED | actual IR byte source PENDING |
| Printer connected UI | IMPLEMENTED state only | transport/CUPS backend PENDING |
| CUPS/PDF printing | NOT YET INTEGRATED | PENDING |
| Power virtual key | UI PRESENT | hardware contract intentionally PENDING |
| Save-state path isolation | LAUNCHER PREPARED | PENDING runtime |
| Linux command/menu installation | PREPARED | packaging smoke PASS; Surface package integration PENDING |
| Reduced dependency closure | IN PROGRESS | full link currently blocked by Qt debugger linkage in donor MAME tree |
| `-validate` | — | PENDING linked reduced binary |
| Surface RT installed stable | — | PENDING |

## Validation performed on T640

The feature driver was copied temporarily into the full `mame-as2k` donor tree under a
restore-on-exit shell guard and compiled with warnings treated as errors. The modified
`alphasma.cpp` compiled successfully and `libmame_as2kdiag.a` was produced.

The subsequent full link did not complete because the donor build attempted to link the Qt
debugger archive without its Qt symbols, producing unresolved `QWidget`, `QObject` and related
references. This is a build/link configuration blocker outside the AS2K driver source; it does
not count as a successful emulator build and must be removed from the reduced stable closure.

Static gates currently pass:

- `AS2K UI static validation: PASS`
- `AS2K stable static installation gate: PASS`

## Current stop line

Do not install this branch on the Surface as the stable emulator yet. The UI and first core/UI
bridge increment now exist, but the reduced binary must link independently, then pass runtime
tests for LCD mirroring, virtual matrix keys and PC Send before installation is promoted.

## Next stable code increment

Keep scope closed:

1. finish the reduced dependency/build closure without the unwanted Qt debugger linkage;
2. build and run the standalone core/UI pair;
3. validate LCD mirror, special-key matrix injection and PC Send Save-As behavior;
4. only after those pass, integrate wired Print/CUPS-PDF as the next isolated increment;
5. IR transport byte-source integration remains separate and must use the real emulated path,
   not a fabricated firmware shortcut.
