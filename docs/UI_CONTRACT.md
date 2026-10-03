# AS2K Emulator stable UI contract

Status: frozen design input for the standalone stable front-end.

This document records the user-visible behavior agreed before implementation. It is a product
contract, not a diagnostic wish-list. Stable must keep hardware behavior in the emulator core
and must not replace AlphaSmart key paths with direct firmware calls.

## Window structure

The application is vertically organized as:

1. AS2K header/status line;
2. always-visible menu bar;
3. AlphaSmart 2000 LCD at its original aspect ratio;
4. IR activity line;
5. mouse-accessible special-key row.

The header begins with `AS2K Emulator` and shows the current external-state summary:
`PC: ON/OFF`, `IR: OFF/ON/TX` and `PRN: ON/OFF`. Recording may add a compact `REC` indicator.
The Workbench build may also show the currently selected payload.

## LCD and scaling

The logical display is 240x36 pixels (40 characters x 4 rows from the two KS0066-compatible
controllers). The stable palette remains the established AlphaSmart grey pair.

The user-selectable presentation modes are exactly:

- 100%;
- 150%;
- 200%;
- full screen.

Full screen never hides the AS2K header, menu bar, IR line or special-key row. It only gives the
application the available display area. The LCD is never stretched out of aspect.

## Menus

Top-level menus are `Archivo`, `Máquina`, `Ver`, `Configuración` and `Ayuda`.
The final application must not expose the generic MAME UI as its normal human-facing identity.

### Archivo

Stable functions include image selection, screenshot, video recording and exit. Selecting a
Firmware ROM or DictROM only stages that image; it does not hot-swap the running machine. The
user applies the selected image explicitly with `Máquina → Reiniciar AlphaSmart`. Firmware
and DictROM may be selected independently before the same reset.

The private working configuration additionally exposes payload selection for STOCK, Payload-0,
Payload-1, Payload-1b, Payload-2 and an external payload file. Selecting a payload affects the
next boot/reset; it is not a hot arbitrary PC jump.

### Máquina

The user can reset the emulated machine and indicate PC, printer and IR attachment states.
There is no separate Power control in stable. Checked state and the header must agree immediately. The wired PC and wired printer
attachments are mutually exclusive because they share the validated host-side connection;
enabling one disables the other. IR remains independent.

The controls represent emulated external conditions. They are not decorative GUI modes.

### Ver

Only 100%, 150%, 200% and full screen are offered.

## Virtual special keys

The mouse row contains:

`Esc | F1 F2 F3 F4 F5 F6 F7 F8 | Print | Spell | Find | Clear | Home | End | Enter | Send`

Ordinary QWERTY keys remain physical-keyboard input. Every virtual special key must create the
same matrix transition as the corresponding AlphaSmart key.

## PC / Send

`PC conectado` controls host attachment. Send remains an ordinary AlphaSmart matrix key.
Text emitted by the firmware is accumulated for the active PC-connection session. Multiple
Send operations during the same connection belong to the same capture.

The Save As dialog appears only when the simulated PC is disconnected and the session contains
captured text. The default format is UTF-8 `.txt`. A connected session with no captured text
must not open a dialog. Cancel discards the pending capture without altering emulator state.

## Printer / Print

`Impresora conectada` controls the emulated printer attachment. Print remains an AlphaSmart
matrix key. A completed wired print job is sent to the stable print backend; on Linux the
human-facing path uses CUPS/GTK and saves PDF through a normal Save As dialog. Pressing Print
must never directly mean "export PDF".

## Infrared

IR does not write TXT or PDF in stable. It exists to demonstrate that the firmware's IR path is
implemented and allowed to run to logical completion.

While transmitting, the header shows `IR: TX` and the IR line displays the most recent bytes in
hexadecimal plus a cumulative byte count. Stable retains only a small rolling display buffer
(64 bytes in R1). At completion the line reports `Transmission complete` and the total byte
count. The same visualization is used whether firmware is sending text or printing by IR.
No Save As dialog is opened for IR.

## Screen capture and video

Screenshot captures the logical LCD, not desktop chrome, and opens Save As for PNG.

Video records only the logical LCD, no audio. The user selects `Iniciar grabación`, later
`Detener y guardar…`, and only then chooses the final MP4 path. Stable uses H.264/MP4 and
nearest-neighbor enlargement so the LCD pixels remain crisp. UI scale (100/150/200/fullscreen)
does not alter the logical recording source.

If the application is closed during recording, it must offer save/discard/cancel rather than
silently losing the capture.

## Ayuda y atajos

`Ayuda → Atajos de teclado…` abre una página de texto local, desplazable y de solo lectura.
La sección principal contiene únicamente combinaciones respaldadas por el manual original
AlphaSmart 2000. Las combinaciones procedentes de notas internas del proyecto que todavía no
están confirmadas específicamente para AS2000 se conservan en una sección aparte y se
identifican explícitamente como referencia no confirmada.

## Stable vs Workbench

The public/stable application does not need payload-development controls. The same front-end
may expose them only under an explicit Workbench mode. Instrumentation, tracing, fuzzing and
Commander-only probes remain outside stable and belong to `as2k-diag`.
