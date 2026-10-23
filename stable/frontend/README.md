# AS2K GTK front-end

> **Frozen VONTAR Stable Public snapshot — 2026-10-18.** The exact public
> application entrypoint is `/usr/local/bin/as2k` →
> `frontend/as2k_session.py` → `frontend/as2k_ui.py` plus the installed
> reduced MAME core. This file documents the underlying GTK UI.
> `as2k_session.py` adds the ROM/DictROM/bootstrap session manager, persistent
> local selections, integrated one-window mode and optional SDL mode, reset
> orchestration, Workbench options and output/NVRAM folder menus. Those functions
> must not be omitted from a VONTAR Stable distribution.
>
> See [VONTAR Stable Public manifest](../docs/VONTAR_STABLE_PUBLIC_20261018.md).
> All external ROMs, payload binaries and user NVRAM remain separate.


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
- 100%, 200%, 300% and full-screen presentation modes;
- original 240x36 LCD aspect with the established two-color palette;
- mouse-accessible special keys in two rows: upper F1-F8, lower Print, Spell, Find, Clear, Home, End,
  Enter and Send;
- workbench-only payload menu enabled with `AS2K_WORKBENCH=1`;
- PNG LCD screenshots with Save As;
- MP4/H.264 LCD recording, no audio, with Start / Stop and Save As;
- PC/Send capture buffer hook: when a connected PC session is closed, a non-empty capture can
  be saved as `.txt`;
- IR activity line with the most recent 64 bytes in hexadecimal and a total byte count;
- wired printer ready-state, physical PD0 serial decoding, completed PCL job delivery and
  GTK Save As to PDF through the CUPS filter chain;
- Firmware ROM and DictROM file selection staged until the user explicitly chooses Reset;
- narrow Linux bridge contract for core integration.

## Bridge contract (R1)

The front-end accepts two optional paths:

- `AS2K_UI_CONTROL_FILE` — append-only newline-delimited commands from the UI to the emulator core;
- `AS2K_UI_EVENT_FILE` — append-only tab-delimited events from the core to the UI;
- `AS2K_UI_FRAME_FILE` — raw LCD mirror, exactly 240x36 bytes, one byte per pixel (`0` or `1`).

When the variables are not set, paths default under `$XDG_RUNTIME_DIR/as2k/` (or a private
`/tmp/as2k-UID/` fallback).

The current command vocabulary is intentionally human-readable and provisional:

- `KEY F1` ... `KEY F8`, `KEY PRINT`, `KEY SPELL`, `KEY FIND`,
  `KEY CLEAR`, `KEY HOME`, `KEY END`, `KEY ENTER`, `KEY SEND`;
- `KEYDOWN <matrix-key>` / `KEYUP <matrix-key>` for ordinary physical host-key make/break events;
- `MACHINE RESET`;
- `PC ON|OFF`, `PRINTER ON|OFF`, `IR ON|OFF`;
- `FIRMWARE <path>`, `DICTROM <path>` stage validated images; `MACHINE RESET` applies them;
- workbench only: `PAYLOAD STOCK|P0|P1|P1B|P2` and `PAYLOAD_FILE <path>`.

The core translates both virtual buttons and ordinary host keyboard make/break events into the
same AlphaSmart keyboard-matrix transitions as the physical machine. The front-end does not call
firmware routines directly.

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

## GTK button layout refinement (22 October 2026)

Only the visible virtual-button area was changed: F1-F8 are on the top row,
and Print, Spell, Find, Clear, Home, End, Enter, Send are on the lower row.
The virtual Esc button was removed, but physical keyboard Escape remains mapped.
Both rows use the existing horizontal scroller on narrow screens. Commands,
GTK LCD scaling, emulation core and session state are untouched.
Headless static regression: `stable/tests/test_virtual_button_rows.py`.

**Centered uniform layout (22 Oct):** both lines have GTK centered alignment,
every button uses the same shared horizontal SizeGroup and a minimum request
of 72×34 GTK logical pixels; longer system fonts can expand all buttons
together without truncating the lower labels. Installed on both VONTAR and
Surf with test/installation PASS, pending GUI reopen to visually confirm.

## Persistent NVRAM regression fix (22 October 2026)

Stable uses MAME's existing 128 KiB NVRAM image at
`~/.local/share/as2k/nvram/asma2k/nvram`. A normal MAME exit saves the
image and MAME reloads it automatically on the next launch. The GTK manager
now requests a native MAME exit using the already-supported Lua autoboot
interface, and waits for completion. It does **not** send SIGTERM/SIGKILL.
Unexpected failure, timeout or an invalid final image blocks a claim of
successful save. No MAME recompilation or additional memory format was needed.

Headless regression: `stable/tests/test_nvram_orderly_shutdown.py`.
Native isolated create/reopen tests and GTK-manager installation passed on
both Surf and VONTAR on 22 October 2026. A new GUI process is required to
use the updated Python; final user-document acceptance remains pending.
Manual selection of alternative NVRAM files belongs to a future increment.

## Native NVRAM file selection (RAM-02, 22 October 2026)

The already existing MAME 128 KiB NVRAM support is retained. The default
image lives at `~/.local/share/as2k/nvram/asma2k/nvram` and is initialized
only if absent. A chosen 131072-byte file can be opened via
`Archivo → Abrir archivo RAM/NVRAM…`, and
`Archivo → Usar RAM predeterminada` restores the normal image.
The last external choice is persisted as `ram_file` in `session.json`.

Each external RAM is mounted through a private MAME-compatible work
directory; a clean exit synchronizes bytes atomically back to the chosen file,
with one recovery backup, fingerprint conflict protection, and a pending marker
that prevents overwriting unsaved workspace contents after an abnormal exit.
It does not add a new RAM format or alter the core.

Static/isolated regression:
`stable/tests/test_nvram_file_selection.py`, in addition to the
`test_nvram_orderly_shutdown.py` gate. Deployed with PASS on VONTAR and Surf;
GUI live-document acceptance is pending.
