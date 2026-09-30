# AS2K stable installation layout

Status: **installation contract prepared; runtime build validation pending Commander/T160**

## System files

The stable variant is the only AS2K emulator installed system-wide.

Default prefix: `/usr/local`.

| Path | Purpose |
|---|---|
| `/usr/local/bin/as2k` | Stable launcher available on `PATH` |
| `/usr/local/libexec/as2k/as2k-bin` | Validated reduced emulator binary |
| `/usr/local/share/applications/as2k.desktop` | Desktop/application-menu entry |

The installer accepts another prefix when explicitly requested.

`as2k-diag` is never installed into these locations.

## Per-user stable data

The launcher uses XDG locations and keeps them independent from the diagnostic working tree:

| Data | Default path |
|---|---|
| MAME configuration | `~/.config/as2k/cfg` |
| NVRAM | `~/.local/share/as2k/nvram` |
| PC Send and other stable output | `~/.local/share/as2k/output` |
| Save states | `~/.local/state/as2k/states` |

The standard `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_STATE_HOME` variables override these roots.

Uninstallation removes program/menu files only. User NVRAM, states, configuration and output are deliberately preserved.

## Firmware and DictROM

Firmware and DictROM are **not installed** and are never copied into the public repository.

The stable driver exposes two mandatory user-loadable image sockets:

1. **Firmware** — accepts a raw 32 KiB executable image (`0x8000`) or a known ZPSD-style dump containing the same first 32 KiB followed by mapper/PAL data (`0x81e5`). Only the executable window is mapped; the source file is never modified.
2. **DictROM** — accepts the 128 KiB (`0x20000`) dictionary image.

Because both are mandatory MAME image devices, starting stable without configured files invokes the emulator's file-selection flow rather than binding the program to fixed ROM-set names or checksums.

Changing a mounted image follows the image-device reset-on-load contract, allowing another compatible firmware/DictROM combination to be tested without rebuilding AS2K.

## Installation

After the reduced binary has passed the build and runtime gate:

```sh
sudo scripts/install-stable.sh /path/to/validated/as2k
```

A non-default prefix can be supplied as the second argument.

The installed command is simply:

```sh
as2k
```

The application-menu entry executes the same launcher and therefore uses the same stable configuration and mutable-data locations.

## Acceptance gate

Installation is not closed until T160/Commander verifies all of the following:

- installer succeeds from a clean reduced build;
- `as2k` starts from an arbitrary working directory;
- the application-menu entry starts the same installed binary;
- missing Firmware and DictROM open the expected image-selection flow;
- a supported external firmware plus DictROM boots normally;
- changing firmware does not require recompilation;
- stable NVRAM persists under the stable XDG data directory;
- PC Send writes only under the stable output directory;
- save states use the stable state directory;
- no `as2k-diag` binary, configuration or mutable state is installed or shared;
- uninstall removes program files without deleting user data.
