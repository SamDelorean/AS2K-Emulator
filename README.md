# AS2K Emulator

A compact, reproducible emulator for the AlphaSmart 2000, derived from the MAME emulation engine and focused on stable human testing and firmware development.

## Status — Stable Public (VONTAR X3, 2026-10-18)

**Canonical public source snapshot:** [VONTAR full release manifest](docs/VONTAR_STABLE_PUBLIC_20261018.md).

This frozen branch reproduces the currently approved VONTAR installation, **including its exact `as2k_session.py` manager, original launcher and existing user-facing accessories**. It is not the early reduced-core preparation build and not the later Surface RT port. The UI manager adds session-aware ROM/DictROM/bootstrap controls, integrated display, Workbench menus, and persistent local selections without bundling any proprietary ROM or payload.

The branch is public source, not a GitHub binary release: no proprietary firmware/DictROM or user NVRAM is shipped, and no precompiled AArch64 executable is attached. Full binary redistribution remains gated by licensing/provenance and corresponding-source checks.

### VONTAR / Armbian ARM64 installation

On an **intentionally selected target** with a clean checkout and a supported Armbian/Debian system:

```sh
git clone --branch release/vontar-stable-public-20261018 https://github.com/SamDelorean/AS2K-Emulator.git
cd AS2K-Emulator
sh install-as2k-vontar.sh --check
sh install-as2k-vontar.sh --install
```

The installer uses the reduced AS2K core and a pinned MAME donor, installs under `/usr/local`, includes the full GTK session manager, keyboard help and PCL/PDF printing helper, and leaves runtime ROMs/NVRAM private and outside the repo. It may install OS dependencies and build tools. See the [full inventory, checksums and qualifications](docs/VONTAR_STABLE_PUBLIC_20261018.md).

### Surface RT

Surface RT (ARMv7/postmarketOS) is a **separate port of the VONTAR reference**. Its toolchain and installed ELF are different. Do not substitute Surface build/install instructions for the frozen VONTAR source snapshot.

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
