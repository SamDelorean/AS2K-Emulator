# Legal and distribution boundary

## Project license

The combined AS2K Emulator distribution is licensed under GPL-2.0-or-later. Source files imported from MAME keep their original copyright notices and SPDX identifiers. Do not remove or replace per-file license metadata.

Before each source import:

1. record the exact upstream repository, revision and path;
2. preserve the original header and authorship;
3. verify that every transitive source dependency has a GPL-compatible license;
4. add the file to the dependency/provenance manifest;
5. distribute corresponding source and build instructions for any released binary.

## Excluded material

Never commit, attach to a release, or embed:

- AlphaSmart firmware or DictROM dumps;
- modified or derived firmware images;
- user NVRAM, RAM images, saved states or document contents;
- private reverse-engineering exports, traces or diagnostic captures;
- credentials, tokens or machine-specific paths.

The stable emulator must request user-supplied ROM and DictROM images through its runtime interface. Normal boot, Direct DictROM bootstrap, image management and save-state features must not modify or redistribute those source images.

## Trademarks and affiliation

“AlphaSmart” and “MAME” are used descriptively to identify compatibility and technical ancestry. This repository is an independent community project and is not endorsed by the MAME project or by the original device manufacturers.

## Stable/`as2k-diag` boundary

Public stable code may contain reproducible emulation, mouse-accessible user controls, ROM selection, RAM/NVRAM management, save states, integer scaling, PC Send and CUPS/PDF printing.

Instrumentation, memory probes, private firmware knowledge, captured documents, low-level printer traces and Commander-specific harnesses remain in the separate private `as2k-diag` TestLab environment. A diagnostic change may return to this repository only as a clean, reviewed commit containing no private evidence or proprietary data.

## Release gate

No public binary release is permitted until the dependency manifest, corresponding-source bundle, license texts, build instructions, firmware-exclusion checks and stable-feature regressions have all passed.
