# AS2K GTK front-end

`as2k_ui.py` is the first implementation increment of the standalone AS2K Emulator identity.
It is deliberately separated from MAME's generic UI. The MAME-derived core remains responsible
for hardware semantics; the GTK front-end owns human-facing menus, status, file dialogs,
virtual special keys and LCD-only media capture.

## Target

The primary Linux target for this increment is the Surface RT running postmarketOS/XFCE.
The front-end uses GTK 3 / PyGObject and keeps rendering work small: the logical LCD is only
240x36 pixels. MP4 recording is delegated to FFmpeg and contains no audio.

## Current status

The standalone UI and core/UI bridge are implemented. Core/runtime gates are closed for the
LCD mirror, virtual matrix keys, PC/Send, wired Print→CUPS-PDF, and Send/Print IrDA
visualization. A live GTK acceptance pass and Surface RT packaging/install remain before the
stable release is promoted.

Implemented in the shell:

- AS2K Emulator identity/header with PC, IR and printer state;
- visible menu bar in normal and full-screen modes;
- 100%, 150%, 200% and full-screen presentation modes;
- original 240x36 LCD aspect with the established two-color palette;
- mouse-accessible special-key row: Power, Esc, F1-F8, Print, Spell, Find, Clear, Home, End,
  Enter and Send;
- workbench-only payload menu enabled with `AS2K_WORKBENCH=1`;
- PNG LCD screenshots with Save As;
- MP4/H.264 LCD recording, no audio, with Start / Stop and Save As;
- PC/Send capture buffer hook: when a connected PC session is closed, a non-empty capture can
  be saved as `.txt`;
- IR activity line with the most recent 64 bytes in hexadecimal and a total byte count;
- wired printer ready-state, physical PD0 serial decoding, completed PCL job delivery and
  GTK Save As to PDF through the CUPS filter chain;
- narrow Linux bridge contract for core integration.

## Bridge contract (R1)

The front-end accepts two optional paths:

- `AS2K_UI_CONTROL_FILE` — append-only newline-delimited commands from the UI to the emulator core;
- `AS2K_UI_EVENT_FILE` — append-only tab-delimited events from the core to the UI;
- `AS2K_UI_FRAME_FILE` — raw LCD mirror, exactly 240x36 bytes, one byte per pixel (`0` or `1`).

When the variables are not set, paths default under `$XDG_RUNTIME_DIR/as2k/` (or a private
`/tmp/as2k-UID/` fallback).

The current command vocabulary is intentionally human-readable and provisional:

- `KEY POWER`, `KEY ESC`, `KEY F1` ... `KEY F8`, `KEY PRINT`, `KEY SPELL`, `KEY FIND`,
  `KEY CLEAR`, `KEY HOME`, `KEY END`, `KEY ENTER`, `KEY SEND`;
- `MACHINE RESET`, `MACHINE POWER`;
- `PC ON|OFF`, `PRINTER ON|OFF`, `IR ON|OFF`;
- `FIRMWARE <path>`, `DICTROM <path>`;
- workbench only: `PAYLOAD STOCK|P0|P1|P1B|P2` and `PAYLOAD_FILE <path>`.

The core must translate virtual key commands into the same keyboard-matrix transitions as the
physical AlphaSmart keys. The front-end must not call firmware routines directly.

The core side implements LCD mirroring, virtual special-key injection through the existing
keyboard matrix, PC-present/Send capture, wired printer/PCL completion, and the recovered
validated IrDA peer. Real IrDA TX bytes are published as IR_BYTES and normal stock firmware
session return publishes IR_DONE. Stable IR never persists TXT, PDF, PCL or RAW captures.

## Keyboard shortcuts help

`Ayuda → Atajos de teclado…` opens `alphasmart_2000_shortcuts.txt` in a read-only
scrollable text window.  The confirmed section is derived from the AlphaSmart 2000 User
Manual (May 1999); project-only shortcut notes that are not yet confirmed for AS2000 are
kept in a separately labelled section rather than silently merged.

## Local syntax gate

```sh
./scripts/validate-ui-static.sh
```

This checks Python syntax and the fixed LCD/media constants without requiring a display server.
