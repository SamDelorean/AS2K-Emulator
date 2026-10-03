# AS2K stable implementation status

Date: 2026-10-02  
Branch: `feature/as2k-stable-ui-r1` (based on `prep/as2k-stable-reduced-r0`)

This table distinguishes source prepared statically from behavior proven by native execution.

| Component | Source status | Native/runtime status |
|---|---|---|
| AS2K-only registration | PREPARED | PENDING |
| External Firmware socket | PREPARED | PENDING |
| External DictROM socket | PREPARED | PENDING |
| No fixed proprietary ROM-set dependency | STATIC PASS | PENDING runtime |
| Normal firmware boot | PRESERVED BY DESIGN | PENDING |
| Direct DictROM bootstrap | PREPARED | PENDING |
| LCD 40x4 core | DONOR/SHARED | PENDING reduced build |
| Standalone AS2K GTK UI shell | PREPARED | Python syntax PASS; live GTK/Surface test PENDING |
| LCD mirror/UI bridge | CONTRACT PREPARED | CORE SIDE PENDING |
| Special-key mouse row | UI PREPARED | CORE MATRIX BRIDGE PENDING |
| 100/150/200/fullscreen UI | PREPARED | LIVE GUI TEST PENDING |
| PNG LCD screenshot | PREPARED | LIVE GUI TEST PENDING |
| MP4/H.264 LCD recording, no audio | PREPARED | FFmpeg/live GUI test PENDING |
| Workbench payload selector | PREPARED | CORE PAYLOAD BRIDGE PENDING |
| Keyboard/F1-F8/sleep-wake | DONOR/SHARED | PENDING reduced build |
| 128 KiB NVRAM/banking | DONOR + external DictROM refactor | PENDING reduced build |
| PC Send physical-port decoding | VALIDATED DONOR + path isolation | PENDING reduced build |
| Send Save-As-on-disconnect UI | PREPARED | CORE EVENT BRIDGE PENDING |
| IR hexadecimal rolling display UI | PREPARED | CORE IR EVENT BRIDGE PENDING |
| Stable output isolation | PREPARED | packaging smoke PASS; emulator runtime PENDING |
| CUPS/PDF printing | NOT YET INTEGRATED | PENDING |
| Save-state path isolation | LAUNCHER PREPARED | PENDING runtime |
| Linux command/menu installation | PREPARED | packaging smoke PASS; Surface package integration PENDING |
| Reduced dependency closure | IN PROGRESS | PENDING |
| `-validate` | — | PENDING |
| Surface RT installed stable | — | PENDING |

## Current stop line

Do not install this branch as the real stable emulator yet.  The standalone UI shell now exists,
but the MAME-derived core must still implement the narrow UI bridge and the reduced binary must
compile and pass its acceptance matrix before the installer is redirected to the new front-end.

## Next stable code increment

Implement the core side of the R1 bridge:

1. export the 240x36 LCD mirror without changing LCD timing or firmware-visible state;
2. accept virtual special-key commands and translate them into the existing matrix path;
3. route PC attachment through the bridge without changing the validated physical-port decoder;
4. emit completed Send-capture and IR-byte events to the UI;
5. keep printer/CUPS integration as the following isolated increment.

Target installation remains the Surface RT/postmarketOS build after native validation.
