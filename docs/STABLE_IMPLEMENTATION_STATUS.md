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

## Current stop line

The reduced core build/link/validate increment is closed. Do not install on the Surface yet:
the next increment is runtime acceptance of the bridge, beginning with the missing Send
capture. Printer/CUPS and real IR byte-source integration remain out of scope until that
runtime bridge gate closes.

## Next stable code increment

Closed scope:

1. determine why the automated PC session reaches `PC connected/disconnected` but does not
   produce `SEND_READY`;
2. compare only two paths: the already validated legacy PC-connected input path versus the
   new UI override path, using the same stock v3.1.4 firmware and the same Send matrix key;
3. fix only the first demonstrated divergence;
4. rerun one deterministic Send capture and require the expected text in the completed
   temporary capture;
5. stop once Send passes or a new dependency outside this scope is proven.

Do not open CUPS, IR, payload loading or Surface installation work inside this gate.
