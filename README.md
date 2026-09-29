# AS2K Emulator

A compact, reproducible emulator for the AlphaSmart 2000, derived from the MAME emulation engine and focused on human testing and firmware development.

## Status

**R0 — baseline and dependency-closure phase.**

The first milestone is a dedicated `as2k` subtarget that:

- builds independently from the full MAME target;
- passes `-validate`;
- boots a user-supplied AlphaSmart 2000 v3.1.4 firmware image;
- preserves the validated keyboard, 40×4 LCD, NVRAM and PC Send behaviour.

No emulator source has been imported into this repository yet. Code will enter only through reviewed, traceable commits after its dependency and license metadata have been verified.

## Intended stable scope

- AlphaSmart 2000 only.
- 40×4 LCD using two KS0066-compatible controllers.
- Keyboard, F1–F8 files, sleep/wake and PC Send.
- 128 KiB NVRAM and the required RAM/DictROM banking.
- Mouse-accessible controls.
- External firmware selection.
- Load, save and clear RAM/NVRAM images.
- Save and restore emulator state.
- Integer display scaling.

Diagnostic probes, memory tracing, automated harnesses, printer capture and Commander-specific controls belong in the separate private TestLab repository. They must not silently alter stable behaviour.

## Firmware and private data

This repository does **not** contain and will not distribute:

- AlphaSmart firmware or DictROM dumps;
- patched or derived firmware images;
- NVRAM/RAM images or saved states;
- private traces, document contents or diagnostic captures.

Users must supply firmware they are legally entitled to use.

## Relationship to MAME

This is an independent reduced distribution based on selected MAME components. It is not affiliated with or endorsed by the MAME project or the original AlphaSmart manufacturers.

Upstream-quality hardware fixes should still be prepared separately in the full MAME tree and offered to MAME when appropriate.

## License

The combined project is distributed under **GPL-2.0-or-later**. Imported files retain their original copyright, attribution and SPDX license identifiers. A large part of the expected AS2K dependency closure is BSD-3-Clause licensed, but the aggregate distribution follows the compatible MAME project license.

See [LICENSE](LICENSE) and [docs/LEGAL_SCOPE.md](docs/LEGAL_SCOPE.md).
