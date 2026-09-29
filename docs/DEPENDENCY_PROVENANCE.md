# Dependency and provenance manifest

This manifest is the gate for importing source into the reduced AS2K distribution. **Planned** does not mean copied or approved. Each row must receive an immutable upstream commit SHA, verified transitive closure and retained SPDX/copyright metadata before import.

| Component | Upstream path | Expected license | State | Purpose |
|---|---|---:|---|---|
| AlphaSmart driver | `src/mame/skeleton/alphasma.cpp` | BSD-3-Clause | Planned | AS2000 machine definition, maps, keyboard, banks and LCD wiring |
| MC68HC11D0 CPU | `src/devices/cpu/mc68hc11/` | BSD-3-Clause | Planned | CPU and disassembler required by AS2000 |
| HD44780/KS0066 LCD | `src/devices/video/hd44780.*` | BSD-3-Clause | Planned | Two-controller 40×4 LCD emulation |
| NVRAM device | `src/devices/machine/nvram.*` | To verify | Planned | Persistent 128 KiB image |
| Emulation core | exact closure TBD | Mixed GPL-compatible | Discovery | Scheduler, devices, memory, save-state and options |
| Minimal UI/render/input | exact closure TBD | Mixed GPL-compatible | Discovery | Human-test menus, input and integer scaling |

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

## R0 exit criteria

R0 is complete only when the minimal source closure:

1. builds as a dedicated `as2k` target;
2. passes `-validate`;
3. boots a locally supplied v3.1.4 firmware image;
4. passes keyboard/LCD, NVRAM and PC Send regressions;
5. contains no firmware, DictROM, NVRAM, state, trace or private diagnostic data.
