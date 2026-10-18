# Dependency and provenance manifest

This manifest is the gate for importing source into the reduced AS2K distribution. **Planned** does not mean copied or approved. Each row must receive an immutable upstream commit SHA, verified transitive closure and retained SPDX/copyright metadata before import.

| Component | Upstream path | Expected license | State | Purpose |
|---|---|---:|---|---|
| AlphaSmart driver | `src/mame/skeleton/alphasma.cpp` | BSD-3-Clause | Imported on prep branch; build pending | AS2000 machine definition, maps, keyboard, banks, LCD wiring and validated physical-port PC Send baseline |
| MC68HC11D0 CPU | `src/devices/cpu/mc68hc11/` | BSD-3-Clause | Planned | CPU and disassembler required by AS2000 |
| HD44780/KS0066 LCD | `src/devices/video/hd44780.*` | BSD-3-Clause | Planned | Two-controller 40×4 LCD emulation |
| NVRAM device | `src/devices/machine/nvram.*` | To verify | Planned | Persistent 128 KiB image |
| Emulation core | exact closure TBD | Mixed GPL-compatible | Discovery | Scheduler, devices, memory, save-state and options |
| Minimal UI/render/input | exact closure TBD | Mixed GPL-compatible | Discovery | Dialogs, human-test menus, input and integer scaling |
| Host output | exact closure TBD | Mixed GPL-compatible | Discovery | PC Send and CUPS/PDF printing |
| DictROM bootstrap support | project code plus verified MAME interfaces | TBD | Design | Reproduce the documented bootstrap preconditions without modifying images |
| Diagnostic interface | private repository only | N/A here | Excluded | Commander controls, probes, traces and harnesses |

## Required fields before import

For every imported file or directory, record:

- upstream repository and immutable commit SHA;
- original path and destination path;
- SPDX identifier and copyright holders;
- direct and generated dependencies;
- reason it is required by the AS2K target;
- local modifications, if any;
- build and regression evidence.

## Baseline references

- Full upstream base: current MAME mainline selected at the start of R0.
- AS2K PC Send behaviour: commit `5901a4595f12fc5a0080647fac76c41522495dc1` from `SamDelorean/mame-as3k`, to be reviewed and transplanted as behaviour rather than by copying divergent branch history.
- Accepted keyboard and XIRQ/STOP corrections are expected to come from the selected current MAME baseline.
- Firmware v3.1.4 is the reference validation baseline, not a hard-coded runtime requirement.

## R0 measurements

Record, for the full MAME baseline and the reduced AS2K target:

- source-tree disk usage;
- Git data separately from derived files;
- clean-build time and peak memory;
- incremental build time after changing only the AS2K driver;
- build-directory size;
- stripped and unstripped executable sizes.

The reduced target must show a material, reproducible improvement. No fixed numeric threshold is assumed before the first baseline measurement.

## R0 exit criteria

R0 is complete only when the minimal source closure:

1. builds as a dedicated `as2k` target;
2. passes `-validate`;
3. boots a user-selected v3.1.4 reference firmware image;
4. leaves selection open for other compatible external firmware images;
5. passes keyboard/LCD, banking, NVRAM, PC Send and CUPS/PDF printing regressions;
6. exercises normal boot and the documented Direct DictROM bootstrap;
7. proves separate stable and `as2k-diag` configuration/data locations;
8. records clean and incremental build metrics plus disk usage;
9. contains no firmware, DictROM, NVRAM, state, trace or private diagnostic data.


## Imported preparation baseline — 2026-09-30

The first traceable AS2K driver donor imported on the preparation branch is:

- repository: `SamDelorean/mame-as3k`
- commit: `5901a4595f12fc5a0080647fac76c41522495dc1`
- source path: `src/mame/skeleton/alphasma.cpp`
- source blob: `fba7023f37f7a89a00d72601ee39234e6ad80231`
- destination: `src/mame/skeleton/alphasma.cpp`

This import is intentionally the unchanged donor file. It is **not yet the reduced stable driver** and is not merge-ready until AS2K-only reduction, external runtime image loading, boot selection and dependency closure have been implemented and compiled. The immutable donor commit is retained so every later transformation can be reviewed against a known validated source.

## VONTAR Stable Public source addition (2026-10-18)

The first public VONTAR full-app source snapshot preserves the application's
session manager, a locally authored Python GTK3/PyGObject program previously
present only in the **functional VONTAR installation**:

| Component | Installed reference | Content fingerprint | Source location |
| --- | --- | --- | --- |
| VONTAR session manager | `/usr/local/libexec/as2k/frontend/as2k_session.py` | SHA-256 `57d0dd376cb8809858d19179373c8d813ff5eb7be9d0a103d6270904e703bf0f`, 23,071 bytes | `frontend/as2k_session.py` |
| Canonical VONTAR launcher | `/usr/local/bin/as2k` | SHA-256 `bc7c2670c82c53f10275a0ea8d83b09f9696930dee72d897e4e7de8f301720a8`, 85 bytes | `packaging/as2k-launcher.sh` |

The session manager imports and extends the existing base GTK frontend and
starts the pre-existing reduced MAME core; it does not embed or distribute
any firmware, DictROM, LCD-controller ROM, payload binary or NVRAM file.
These source components were compared against installed reference hashes.
The existing source and build provenance remains rooted in the frozen
AS2K source commit `36996b91053969661371dc067d49026fab367a47`
and the MAME donor `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`.

This documents **source provenance**, not a completed fresh binary release
license audit. For formal binary redistribution, close the corresponding-source
and transitive-dependency gate in `docs/LEGAL_SCOPE.md`.
