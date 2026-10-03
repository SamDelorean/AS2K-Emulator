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

## Current stop line

LCD mirror, virtual special-key injection, reduced build/validate and PC/Send core bridge are
closed. Do not reopen those gates without contrary evidence.

The next isolated implementation gate is **wired Print → host PDF**. IR remains out of scope
for that increment.

## Next stable code increment

Closed scope for wired printing:

1. extract/reuse the already validated wired printer signal path from the existing diagnostic
   implementation rather than inventing a new firmware shortcut;
2. expose `Impresora conectada` as the corresponding hardware-visible ready state;
3. collect one completed wired print job while preserving Print as a normal matrix key;
4. pass that completed job to one host print/PDF backend and open the GTK Save-As flow only
   after firmware transmission completes;
5. require one short stock-v3.1.4 print job to produce a valid PDF, then STOP.

Do not add IR, payload execution, broader printer emulation or Surface installation inside
this gate.
