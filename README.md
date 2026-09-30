# AS2K Emulator

A compact, reproducible emulator for the AlphaSmart 2000, derived from the MAME emulation engine and focused on stable human testing and firmware development.

## Status

**R0 — stable source shaping and dependency-closure phase.**

The first milestone is a dedicated `as2k` subtarget that:

- builds independently from the full MAME target;
- passes `-validate`;
- boots a user-selected AlphaSmart 2000 firmware image;
- uses v3.1.4 as the reference validation baseline without hard-wiring the emulator to that version;
- preserves the validated keyboard, 40×4 LCD, NVRAM, PC Send and printing behaviour;
- demonstrates the expected reduction in clean-build time, incremental-build time and disk use.

The first traceable AS2K driver donor has now been imported on the preparation branch `prep/as2k-stable-reduced-r0`. Stable source shaping is in progress there; `main` remains the release baseline until native compilation and runtime validation close R0.

The preparation branch already removes fixed proprietary ROM-set declarations, exposes mandatory external Firmware and DictROM image devices, isolates stable mutable data/output, and contains the system-installation launcher/desktop scripts. Direct DictROM Bootstrap, stable printing completion and the reduced dependency closure remain build-gated work.

## Two functional variants

Only two functional AS2K emulator variants are intended on the development machine:

1. **AS2K stable** — built from this public repository and installed correctly in the system as the normal emulator and human-test bench. It must be reachable through an application-menu launcher and the stable `as2k` command.
2. **`as2k-diag`** — private instrumented TestLab build for Commander, development and automated diagnostics. It remains executable from its private Git working directory through a project-local launcher and is not installed system-wide.

They must share the same hardware behaviour, image formats and stable regression contract. Instrumentation must not silently change emulated behaviour. See [docs/RUNTIME_VARIANTS.md](docs/RUNTIME_VARIANTS.md) and [docs/INSTALLATION_AND_LAUNCHERS.md](docs/INSTALLATION_AND_LAUNCHERS.md).

## Intended stable scope

- AlphaSmart 2000 only.
- 40×4 LCD using two KS0066-compatible controllers.
- Complete keyboard behaviour, F1–F8 files and sleep/wake.
- Persistent 128 KiB NVRAM and required RAM/DictROM banking.
- Mouse-accessible menus and controls.
- Interactive firmware selection dialog; no single firmware version is embedded or required by design.
- Load, save and clear RAM/NVRAM images.
- Save and restore emulator state.
- Integer display scaling for legible multiples of the original display.
- Normal firmware boot.
- Direct DictROM bootstrap that reproduces only the required bootstrap preconditions; it is not an arbitrary PC jump and never modifies the selected ROM or DictROM images.
- PC Send text output.
- Stable printing through CUPS/PDF for human tests.
- Separate configuration and mutable-data locations from `as2k-diag`.

Low-level printer capture, memory tracing, probes, automated harnesses and Commander-specific controls belong in the private `as2k-diag` TestLab environment.

## Firmware and private data

This repository does **not** contain and will not distribute:

- AlphaSmart firmware or DictROM dumps;
- patched or derived firmware images;
- NVRAM/RAM images or saved states;
- private traces, document contents or diagnostic captures.

Users must supply firmware and DictROM images they are legally entitled to use. Runtime selection and bootstrap features operate on those external images without modifying them.

## Repository and disk policy

The full MAME tree remains available for preparing clean upstream contributions. Existing Git repositories, Git worktrees and Git-backed project folders are preserved; this migration does not authorize deleting them.

Disk reduction targets derived material only: installed duplicate executables, build directories, object files, caches, temporary files, copied runtime data and other reproducible artifacts. Cleanup occurs only after inventory and reproducibility checks.

## Relationship to MAME

This is an independent reduced distribution based on selected MAME components. It is not affiliated with or endorsed by the MAME project or the original AlphaSmart manufacturers.

Upstream-quality hardware fixes should still be prepared separately in the full MAME tree and offered to MAME when appropriate.

## License

The combined project is distributed under **GPL-2.0-or-later**. Imported files retain their original copyright, attribution and SPDX license identifiers. A large part of the expected AS2K dependency closure is BSD-3-Clause licensed, but the aggregate distribution follows the compatible MAME project license.

See [LICENSE](LICENSE), [docs/LEGAL_SCOPE.md](docs/LEGAL_SCOPE.md), [docs/DEPENDENCY_PROVENANCE.md](docs/DEPENDENCY_PROVENANCE.md) and [docs/KNOWLEDGE_LIBRARY.md](docs/KNOWLEDGE_LIBRARY.md).
