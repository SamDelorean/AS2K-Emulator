# Project knowledge library

The reduced emulator must save disk space without discarding project knowledge.

## Two-layer model

### Private engineering library

The private project library is the authoritative home for firmware hashes, hardware research, reverse-engineering evidence, memory maps, negative results, traces and TestLab material. Its canonical entry point is the AS2000 engineering index; its compact technical digest is `AS2K_KNOWLEDGE.md`.

Private evidence must never be copied into this public repository merely to make it easier to access.

### Public emulator documentation

This repository contains the curated public subset required to understand, build, test and maintain the stable emulator:

- architecture and hardware contracts;
- source provenance and license metadata;
- build and release instructions;
- public regression specifications;
- decisions that affect stable behaviour;
- links to public upstream commits and issues.

## Preservation classes

| Class | Meaning | Retention |
|---|---|---|
| Canonical | Current source of truth | Keep active and indexed |
| Active | Open work with a defined next gate | Keep until closed |
| Historical | Superseded but uniquely useful evidence | Archive with successor recorded |
| Private evidence | Proprietary or sensitive inputs/results | Keep outside public Git |
| Regenerable | Builds, caches and derived outputs | Delete after reproducibility check |
| Public | Clean code and documentation | Keep in this repository |

## Git preservation rule

All existing Git repositories, Git worktrees and Git-backed project folders are preserved. Migration to the reduced emulator does not authorize deleting, flattening or replacing them.

Space recovery is limited to derived or duplicated runtime material, including:

- compiled executables and object trees;
- duplicate system installations;
- build and compiler caches;
- temporary files and test outputs;
- copied NVRAM, states and runtime images after their authoritative private location is confirmed;
- other artifacts proven reproducible from preserved sources and instructions.

## Cleanup gate

No derived artifact or uploaded backup may be removed until:

1. unpushed commits and unique files are inventoried;
2. useful scripts and documentation have a canonical destination;
3. stable behaviour and `as2k-diag` instrumentation are separated;
4. the reduced target builds and passes its regressions;
5. the private index records the canonical locations;
6. regeneration instructions have been tested;
7. before/after disk usage has been recorded.

The goal is one current copy of knowledge and minimal derived storage, not deletion of Git history or engineering sources.
