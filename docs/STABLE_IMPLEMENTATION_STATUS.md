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
| IR hexadecimal display UI | IMPLEMENTED | SEND/PRINT RUNTIME PASS; no file persistence |
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

## IrDA transport visualization — PASS

The IR gate is closed by **recovering the already validated implementation**, not by
reconstructing the protocol.

The stable build now stages the previously proven MC68HC11 PA7/PAI pulse-accumulator support
and firmware-defined TX/session observers, and reuses the validated virtual IrDA peer. The
previously proven PA6 memory-map behavior was also restored: peripheral/DictROM locations
overlay RAM while ordinary addresses remain RAM-backed, which is required for asynchronous
IrDA interrupt stack traffic.

Stable-specific adaptation is deliberately limited to output policy:

- actual firmware-transmitted bytes are emitted to the existing `IR_BYTES` UI event;
- the completed stock Send/Print return emits `IR_DONE`;
- the old engineering RAW/TXT/PCL/PDF sinks are not present in stable;
- the frontend retains only its rolling hexadecimal display and byte counter.

The regression reuses the historical validated stock-v3.1.4 fixtures independently:
`run2-final/nvram` for Send and `run3-print-final2/nvram` for Print.

Observed T640 result:

```text
AS2K reduced core build: PASS
AS2K IR SEND runtime: PASS bytes=271
AS2K IR PRINT runtime: PASS bytes=808
AS2K UI IR runtime: PASS
```

The runtime gate also rejects any TXT/PDF/PCL/PRN artifact in the IR output directory, so
IR remains visualization-only as required.

## Autonomous GTK SH acceptance attempt — BLOCKED BY HOST ENVIRONMENT

The graphical acceptance is now packaged as `scripts/test-ui-gtk-live.sh` and is designed to
run autonomously without supervising compilation or execution. It does not rebuild the core.

The first autonomous run exposed a real frontend integration defect: PyGObject could load Gdk
4 before the GTK3 frontend imported Gdk. The frontend now explicitly pins `Gtk 3.0`,
`Gdk 3.0` and `GdkPixbuf 2.0`; that defect is fixed in source.

The subsequent autonomous SH run is blocked by the T640 remote-shell environment, not by an
emulator assertion: the shell can see X11 display `:0` but has no Xauthority permission, and
`xvfb-run` is not installed. The host also lacks `ffmpeg`; the SH treats that separately as
an MP4-test blocker so the rest of the GTK checks can still run once a usable display exists.

No compilation was launched for this GTK acceptance gate and no execution was polled.

## Current stop line

Reduced build/validate, LCD bridge, virtual matrix keys, PC/Send, wired Print→CUPS-PDF and
Send/Print IrDA visualization are now closed at core/runtime level. Do not reopen those gates
without contrary evidence.

The remaining pre-Surface work is a **single live GTK acceptance pass** for the already
implemented frontend behavior: visible LCD, menu/status updates, Send Save-As, wired Print
PDF Save-As, IR rolling hex/completion, screenshot and video controls.

## Next stable code increment

Closed scope:

1. run the existing core and GTK frontend together in one graphical session;
2. exercise only the already implemented UI paths listed above;
3. correct integration defects only—no protocol/hardware re-analysis;
4. when the live GTK gate passes, prepare the postmarketOS/Surface RT installation package
   and launcher as the following increment.

Payload execution and unrelated diagnostic work remain out of scope.
