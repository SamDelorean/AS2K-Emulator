# Runtime variants and feature contract

This document is the canonical product boundary for the reduced AS2K emulator.

## Local topology

| Property | AS2K stable | `as2k-diag` private TestLab |
|---|---|---|
| Primary use | Human tests and normal daily use | Commander automation, development and diagnostics |
| Source visibility | Public | Private |
| Installation | Installed correctly in the system | Not installed; executed from its private Git working/build directory |
| User access | Application-menu launcher plus stable `as2k` command; optional desktop shortcut | Project-local `run-as2k-diag` launcher and Commander entrypoint |
| Launcher target | Installed stable binary, never a temporary build path | Private repository-relative executable and diagnostic configuration |
| Hardware behaviour | Canonical stable contract | Must match stable unless an explicitly labelled diagnostic fault injection is active |
| Configuration | Stable-specific location | Separate diagnostic-specific location |
| Mutable images/states | External, user-controlled | External, isolated from stable by default |
| Instrumentation | None exclusive to diagnostics | Traces, probes, memory watch, harnesses and deterministic control |
| Printing | CUPS/PDF user output | May additionally capture low-level printer activity and traces |

Only these two functional variants should be installed or built for routine use. This rule does not delete or forbid preservation of existing Git repositories and worktrees.

Every launcher must work from an arbitrary current directory, display which variant is being started and avoid hard-coded firmware, DictROM, NVRAM or user-document paths. See [INSTALLATION_AND_LAUNCHERS.md](INSTALLATION_AND_LAUNCHERS.md).

## Stable human-test features

The stable emulator must provide:

- user-selected ROM and DictROM through mouse-accessible dialogs;
- no embedded proprietary firmware and no design dependency on one fixed ROM version;
- v3.1.4 as the reference regression baseline;
- normal firmware boot;
- direct DictROM bootstrap as defined below;
- LCD 40×4, complete keyboard behaviour, F1–F8, sleep/wake and banking;
- persistent 128 KiB NVRAM;
- load, save and clear operations for RAM/NVRAM images;
- save and restore emulator state;
- integer display scaling;
- PC Send text output;
- printing through CUPS/PDF;
- stable-specific configuration and data locations.

## Direct DictROM bootstrap

Direct DictROM boot models the action of the ATtiny85 bootstrap being developed for physical hardware, but is simplified for the emulator.

It must:

1. leave the selected ROM and DictROM image bytes unchanged;
2. reproduce only the processor, memory, banking, stack and device preconditions demonstrated to be required by the bootstrap contract;
3. transfer control through a documented DictROM entry contract;
4. avoid an unexplained or arbitrary program-counter assignment;
5. produce a repeatable state suitable for both human and automated tests;
6. fail clearly when an image or required precondition is incompatible.

The normal boot path remains available and is the baseline control.

## `as2k-diag` controls

The private diagnostic variant may expose deterministic Commander operations for:

- start, stop, reset and controlled stepping;
- selecting external ROM/DictROM images;
- loading, saving, clearing and restoring RAM/NVRAM;
- loading and restoring emulator states;
- keyboard injection and PC Send capture;
- CUPS/PDF verification and low-level printer capture;
- trace capture, breakpoints, memory watch and hardware probes;
- regression harness execution and machine-readable results.

These capabilities must remain isolated from stable configuration and must not require modifying proprietary images.

For Profile 1 G2.7, the minimum instrumentation and handoff contract are defined in [PROFILE1_G2_7_DIAG_FIRST_BUILD.md](PROFILE1_G2_7_DIAG_FIRST_BUILD.md). The T160 reimplantation worker must leave `as2k-diag` compiled, repository-local, instrumented and smoke-tested before publishing the exact `trabajos terminados` handoff commit. Profile 1 must not consume Commander before that commit and should not rebuild `as2k-diag` after handoff unless a concrete instrumentation defect is demonstrated.

## Shared regression contract

A stable change is acceptable only if both variants agree on:

- boot-visible CPU and hardware state;
- LCD and keyboard behaviour;
- banking and persistent NVRAM;
- PC Send output;
- printing semantics at the stable interface;
- RAM/NVRAM and save-state formats;
- normal and DictROM bootstrap outcomes.

Diagnostic-only metadata may differ, but emulated results may not.
