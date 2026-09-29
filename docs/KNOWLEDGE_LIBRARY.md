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

## Migration gate

No MAME tree, worktree, tool directory or uploaded backup may be removed until:

1. unpushed commits and unique files are inventoried;
2. useful scripts and documentation are assigned a canonical destination;
3. stable behaviour and TestLab instrumentation are separated;
4. the reduced target builds and passes its regressions;
5. the private index records the new canonical locations;
6. regenerable artifacts are distinguishable from irreplaceable evidence.

The goal is one current copy of knowledge, not one copy of every intermediate artifact.
