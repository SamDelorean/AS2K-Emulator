# AS2K stable implementation status

Date: 2026-10-02  
Branch: `feature/as2k-stable-ui-r1` (based on `prep/as2k-stable-reduced-r0`)

This table distinguishes source prepared statically from behavior proven by native execution.

| Component | Source status | Native/runtime status |
|---|---|---|
| AS2K-only registration | IMPLEMENTED | REDUCED BUILD PASS |
| External Firmware socket | PREPARED | PENDING UI load bridge |
| External DictROM socket | PREPARED | PENDING UI load bridge |
| No fixed proprietary ROM-set dependency | STATIC PASS | REDUCED BUILD/VALIDATE PASS |
| Normal firmware boot | PRESERVED BY DESIGN | PENDING full runtime |
| Direct DictROM bootstrap | PREPARED | PENDING full runtime |
| LCD 40x4 core | DONOR/SHARED | DRIVER COMPILE PASS |
| Standalone AS2K GTK UI shell | IMPLEMENTED | Python static gate PASS; live Surface test PENDING |
| LCD mirror core→UI | IMPLEMENTED | RUNTIME PASS (8640-byte framebuffer) |
| Mouse special keys→matrix | IMPLEMENTED | RUNTIME PASS (Find + Send) |
| 100/150/200/fullscreen UI | IMPLEMENTED | live GUI test PENDING |
| PNG LCD screenshot | IMPLEMENTED | live GUI test PENDING |
| MP4/H.264 LCD recording, no audio | IMPLEMENTED | FFmpeg/live GUI test PENDING |
| Ayuda→Atajos de teclado | IMPLEMENTED | static gate PASS; live GUI test PENDING |
| Workbench payload selector | UI IMPLEMENTED | core payload/load bridge PENDING |
| Keyboard/F1-F8/sleep-wake | DONOR/SHARED | DRIVER COMPILE PASS |
| 128 KiB NVRAM/banking | DONOR + external DictROM refactor | DRIVER COMPILE PASS |
| PC host-present state from UI | IMPLEMENTED through existing PA host-sense path | RUNTIME PASS |
| PC Send physical-port decoding | VALIDATED DONOR + UI session integration | RUNTIME PASS |
| Send Save-As-on-disconnect | IMPLEMENTED core event + GTK Save As | CORE EVENT PASS; live GTK dialog PENDING |
| IR hexadecimal display UI | IMPLEMENTED | actual IR byte source PENDING |
| Printer connected UI | IMPLEMENTED | PA0 ready-state + wired transport RUNTIME PASS |
| CUPS/PDF printing | IMPLEMENTED for verified HP/PCL-text subset | RUNTIME PASS; live GTK Save As PENDING |
| Power virtual key | UI PRESENT | hardware contract intentionally PENDING |
| Save-state path isolation | LAUNCHER PREPARED | PENDING runtime |
| Linux command/menu installation | PREPARED | packaging smoke PASS; Surface package integration PENDING |
| Reduced dependency closure | CLOSED | REDUCED BUILD PASS |
| `-validate` | — | PASS |
| Surface RT installed stable | — | PENDING |

## Validation performed on T640

The reduced-core build closure is now **PASS**.

A reproducible builder is committed as `scripts/build-stable-core.sh`. It stages the reduced
driver into a donor MAME tree under a restore-on-exit guard, removes only the stale derived
Qt-debugger archive/object directories, temporarily removes the obsolete `asmapro` entry from
the donor `mame.lst` mapping for `skeleton/alphasma.cpp`, builds with `USE_QTDEBUG=0`,
runs `./as2k -validate`, then copies the validated executable to the ignored
`out/as2k-bin` path.

T640 result:

- one source file;
- one driver (`asma2k`);
- reduced executable linked successfully as `as2k`;
- `./as2k -validate` returned success;
- final builder result: `AS2K reduced core build: PASS`;
- validated artifact: `out/as2k-bin`.

The earlier Qt failure was confirmed to be stale `libqtdbg_sdl.a` reuse after changing
`USE_QTDEBUG`; the builder now invalidates only those derived debugger artifacts. The
subsequent `driver_asmapro` link failure was caused by MAME's global list still associating
the donor source file with AlphaSmart Pro; the temporary list filter closes that mismatch
without modifying the donor tree permanently.

A first runtime bridge smoke was also executed after the build closure. The 240x36 LCD mirror
was produced at exactly 8640 bytes, and the virtual `Find` command changed the framebuffer,
so the screen path and special-key matrix path are both live. `PC ON` and `PC OFF` reached
the core event stream. The same smoke did **not** yet produce `SEND_READY`; that is the next
bounded runtime issue and is not being counted as a Send PASS.

Static gates currently pass:

- `AS2K UI static validation: PASS`
- `AS2K stable static installation gate: PASS`

## Send runtime bridge — PASS

The bounded Send gate is closed.

The first smoke failure was not a core/UI defect. That test pressed Send after a fixed delay
without waiting for the stock v3.1.4 firmware to reach its connected-PC ready state. The
historical validated regression waits for PC=$80E5 before pressing Send. Repeating the test
with that same readiness criterion showed no divergence between the legacy Pause/Break
PC-connected path and the new UI override.

Deterministic comparison on T640:

- legacy PC-connected input + physical matrix Send: captured `abc 123`;
- UI `PC ON` + `KEY SEND` through the matrix overlay: captured `abc 123`;
- UI two-Send session before disconnect: captured exactly `abc 123abc 123`;
- disconnect emitted exactly one `SEND_READY` event pointing at the completed temporary file;
- no PC frame errors were observed.

The reproducible regression is committed as `scripts/test-ui-send-runtime.sh`. It takes the
validated reduced core, user-supplied Firmware/DictROM, a private prepared NVRAM seed and the
expected single-Send text. It performs two Send operations in one PC session and requires the
concatenated output before reporting PASS. Proprietary ROM/NVRAM data are not stored in Git.

Observed T640 result:

```text
AS2K UI Send runtime: PASS
capture: abc 123abc 123
```

The GTK Save-As dialog itself still requires a live graphical-session acceptance test, but the
firmware transmission, physical-port decoder, session boundary, completed-capture event and
exact captured content are now dynamically proven through the new bridge.

## Wired Print → CUPS PDF — PASS

The wired printing gate is closed for the verified stock-v3.1.4 HP/PCL-text subset.

The implementation reuses the previously validated physical signal model: with
`Impresora conectada`, PA0 reports printer-ready and PD0 edges are decoded using the same
2 MHz timing and inverted 8N1 sampling points already established by the diagnostic work.
Print remains a normal AlphaSmart keyboard-matrix event; no firmware routine or program
counter hook was added.

The stable core now opens a temporary PCL capture on the first valid printer byte and closes
the job only when the observed complete HP/PCL terminator
`ESC &l0H ESC E` is received. A completed job emits exactly one
`PRINT_READY <path>` event to the GTK front-end. The front-end then opens the normal
Save-As flow and converts the verified text subset to PDF through `cupsfilter` with a
generic PDF PPD. Unsupported PCL fails closed and preserves the raw PCL for diagnosis.

T640 deterministic runtime result from a real stock-v3.1.4 Print operation:

```text
STATUS    Printer connected
PRINT_READY    .../.as2k-print-pending-1.pcl
AS2K wired PCL capture: PASS bytes=77
AS2K_CUPS_PDF_PASS pages=1 bytes=41318
AS2K wired CUPS PDF: PASS bytes=41318
AS2K UI Print runtime: PASS
```

The captured physical stream had the expected PCL prologue/terminator and contained
`AS2K PRINT TEST`. The resulting file was recognized as a one-page PDF. The reproducible
regression is `scripts/test-ui-print-runtime.sh`.

The wired printer and PC keyboard are now treated as mutually exclusive host-side wired
attachments, matching the validated PA0/PA2 model. IR remains independent.

## Current stop line

Reduced build/validate, LCD bridge, special-key matrix injection, PC/Send and wired
Print→CUPS-PDF are closed at core/runtime level. The GTK Save-As dialogs still need one live
graphical acceptance pass before Surface installation.

The next isolated implementation gate is **IR transport visualization**.

## Next stable code increment

Closed scope for IR:

1. recover the already established IR signal/byte source from the diagnostic implementation;
2. expose activity only when `Infrarrojo activo` is enabled;
3. emit real transmitted bytes to the existing `IR_BYTES` event path and terminate with
   `IR_DONE`;
4. show only the rolling hexadecimal display/count already specified;
5. verify one Send-over-IR and one Print-over-IR transmission reaches logical completion
   without TXT/PDF creation, then STOP.

Do not add payload execution, broader IrDA protocol emulation or Surface installation inside
this gate.
