# AS2K stable implementation status

Date: 2026-09-30  
Branch: `prep/as2k-stable-reduced-r0`

This table distinguishes source prepared statically from behavior proven by native execution.

| Component | Source status | Native/runtime status |
|---|---|---|
| AS2K-only registration | PREPARED | PENDING |
| External Firmware socket | PREPARED | PENDING |
| External DictROM socket | PREPARED | PENDING |
| No fixed proprietary ROM-set dependency | STATIC PASS | PENDING runtime |
| Normal firmware boot | PRESERVED BY DESIGN | PENDING |
| Direct DictROM bootstrap | PREPARED | PENDING |
| LCD 40x4 | DONOR/SHARED | PENDING reduced build |
| Keyboard/F1-F8/sleep-wake | DONOR/SHARED | PENDING reduced build |
| 128 KiB NVRAM/banking | DONOR + external DictROM refactor | PENDING reduced build |
| PC Send physical-port decoding | VALIDATED DONOR + path isolation | PENDING reduced build |
| Stable output isolation | PREPARED | packaging smoke PASS; emulator runtime PENDING |
| CUPS/PDF printing | NOT YET INTEGRATED | PENDING |
| Save-state path isolation | LAUNCHER PREPARED | PENDING runtime |
| Linux command/menu installation | PREPARED | packaging smoke PASS; T160 PENDING |
| Reduced dependency closure | IN PROGRESS | PENDING |
| `-validate` | — | PENDING |
| T160 installed stable | — | PENDING |

## Current stop line

Do not install the branch as the real stable emulator yet. The installer is ready to consume a validated binary, but the binary itself does not become installable until the dependency closure compiles and the native acceptance matrix passes.

## Next stable code increment

Integrate the stable Print/CUPS-PDF path without importing diagnostic probes, then complete the dedicated reduced build closure. Runtime validation waits for Commander/T160.
