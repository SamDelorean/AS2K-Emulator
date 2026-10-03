# Surface RT / postmarketOS local installation

## Unattended Surface installer

For the current Surface RT/postmarketOS target use the frozen installer:

```sh
sh install-as2k-surface.sh
```

It is fully non-interactive: it installs all Alpine/postmarketOS build and runtime dependencies,
checks out the exact AS2K/MAME revisions already validated on the T640, compiles locally with one
job by default, installs the application and desktop launcher, configures the private ROM images,
and finishes with static/build validation. No Commander polling or runtime instrumentation is
part of this flow.

Before starting, place `AS2000_v3.1.4.bin` and `dictrom.bin` beside the SH, or define
`AS2K_FIRMWARE` and `AS2K_DICTROM`. Missing images cause an immediate fail before package
installation begins.

This is the user-facing installation path for AS2K Emulator.

The installation remains intentionally simple: download one shell script, keep the private
Firmware and DictROM available locally, then execute the script. The script compiles the reduced
AS2K core on the Surface itself and installs the complete GTK application.

## Files to have together

Place these files in the same directory if possible:

- `install-as2k.sh`
- `AS2000_v3.1.4.bin` — user-supplied private firmware
- `dictrom.bin` — user-supplied private DictROM

The image names are conveniences only. They are never committed to the repository.

If the images use different names, the script asks for their paths interactively. The same
paths may also be supplied through `AS2K_FIRMWARE` and `AS2K_DICTROM`.

## Run

Normal user-supervised installation:

```sh
sh install-as2k.sh
```

The script asks once before downloading/installing packages. After confirmation, package
installation proceeds without repeated yes/no questions. `apt-get` uses `-y` and a
noninteractive frontend; Alpine `apk add` normally installs without confirmation.

For an unattended run, use:

```sh
AS2K_ASSUME_YES=1 sh install-as2k.sh
```

In unattended mode the script does not wait for package-manager or Git prompts. If it is
already running as root (for example through an authorized Commander session), it executes
privileged steps directly; otherwise it requires passwordless/noninteractive `sudo`. Firmware
and DictROM paths must already be supplied through `AS2K_FIRMWARE` / `AS2K_DICTROM` or the
expected files must be beside the SH.

The script performs the following work in sequence:

1. finds the private Firmware and DictROM before spending time compiling;
2. installs the required build/runtime packages using `apk` on postmarketOS/Alpine
   (with an `apt-get` fallback for Debian-family test hosts);
3. creates a shallow local build tree under `~/as2k-local-build`;
4. downloads the AS2K Emulator source and the compatible MAME donor tree;
5. runs the stable static gate;
6. compiles the reduced AS2K target locally with `AS2K_JOBS=1` by default;
7. runs the core `-validate` gate as part of the existing builder;
8. installs core, GTK frontend, PDF helper and shortcut help under `/usr/local`;
9. copies the private Firmware/DictROM into `~/.config/as2k/` with user-only permissions;
10. installs the application-menu entry and, when a desktop directory exists, a desktop shortcut;
11. validates the installed core and Python frontend.

The source/build directories are retained after installation. Existing repositories are never
deleted or reset by this installer.

## Installed launcher

`/usr/local/bin/as2k` launches the reduced core and GTK frontend together. The core runs with
its generic MAME window disabled; the GTK application is the visible AS2K Emulator interface.

Mutable state is separated under the normal XDG locations:

- configuration: `~/.config/as2k/`
- NVRAM/output: `~/.local/share/as2k/`
- save states/log: `~/.local/state/as2k/`
- runtime queues/LCD bridge: `$XDG_RUNTIME_DIR/as2k-UID/` (or `/tmp/as2k-UID/`)

## Build controls

The default is deliberately conservative for Surface RT:

```sh
AS2K_JOBS=1 sh install-as2k.sh
```

A higher job count can be selected explicitly if desired.

## Validation policy

The installer performs only automated static/build checks. The installed stable emulator is not
instrumented, so functional testing is intentionally manual.

After installation, the user verifies normal typing, LCD behavior, special keys, manual
ROM/DictROM selection followed by Reset, and the visible save/capture flows directly in the GUI.
No background supervisor or Commander polling is required.

## Failure policy

The script uses `set -eu` and stops on the first failed installation/build/validation step.
It does not continue into a partial installation after a compile failure.

The normal repair workflow is therefore: preserve the exact failing terminal output, correct
that single blocker, and rerun the same installer. Do not open unrelated emulator-development
fronts from an installation failure.
