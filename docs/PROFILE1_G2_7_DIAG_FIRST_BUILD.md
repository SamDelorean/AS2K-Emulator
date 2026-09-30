# Profile 1 G2.7 — first `as2k-diag` build contract

Date: 2026-09-30

Status: **PREPARED / WAITING FOR COMPILED+INSTRUMENTED AS2K-DIAG HANDOFF**

This document defines the minimum diagnostic-emulator capability required to
resume Profile 1 G2.7 without spending Commander calls on exploratory work.

## External readiness gate

Do not use Commander from the Profile 1 front until the T160 reimplantation
worker has completed the emulator work and published the exact handoff commit:

`trabajos terminados`

That commit is valid only after the worker has left `as2k-diag` physically
compiled on the T160, repository-local, launchable and instrumented for the
current Profile 1 contract, with its required smoke/regression checks completed.
The handoff is not merely a clean-machine or source-preparation signal.

Before that commit exists, the Profile 1 worker remains static-only.

## Scope of the first diagnostic build

The first `as2k-diag` build is a private, repository-local diagnostic target.
It is not installed system-wide and must not alter the stable installation.

It must provide the following minimum capabilities:

1. deterministic start, stop/reset and controlled execution suitable for Commander;
2. external selection of ROM, DictROM and NVRAM/state inputs, with no proprietary
   image committed or modified in Git;
3. diagnostic configuration, NVRAM, state, logs and captures isolated from stable;
4. a repository-local `run-as2k-diag` entrypoint that works from an arbitrary
   current directory and reports that the diagnostic variant is active;
5. a deterministic way to feed a MAME debugger command file to the AS2K CPU;
6. persistent capture of debugger trace/log output to a known diagnostic path;
7. no diagnostic-only behavior change to the emulated AS2K unless explicitly
   enabled and labelled as fault injection.

### Closed instrumentation set v1 required at handoff

The T160 reimplantation worker must compile and smoke-test `as2k-diag` with:

- stack watermark/guard with the Profile 1 62-byte stack limit;
- bank/view restoration guard;
- configurable PC-region guard;
- configurable RAM/ROM map and reservation guard;
- metadata snapshot/checksum;
- deterministic reset/crash trigger;
- machine-readable run record, preferably JSONL;
- manifest/configuration-driven control so later Profile 1 tests do not require
  recompiling the emulator merely to change watched regions or limits.

Generic tracing/fuzzing is not part of v1 unless a direct blocker requires it.

## Debugger primitives required by Profile 1 G2.7

The existing Profile 1 generator
`tools/render_profile1_debugger_mame_cmd.py` depends on MAME debugger support
for these command/expression forms:

- `trace ... noloop|logerror`
- `rp` / register-point conditions and actions
- `bp` / address breakpoints
- `wpset` / write watchpoints
- `logerror`
- `g`
- debugger temporaries `temp0` and `temp1`
- HC11 register expressions `pc` and `sp`
- watchpoint expressions `wpaddr` and `wpdata`

The first diagnostic build is acceptable for G2.7 only when a small smoke
script using those primitives executes without parser errors and produces the
expected trace/log files.

No emulator-specific symbol loader is required for this gate: the Profile 1
generator resolves linked symbols through the HC11 `nm` map and emits numeric
breakpoint addresses.

## Pre-placement stack probe

G2.7 cannot authorize an internal-RAM bridge interval before measuring stack
headroom.

Therefore `as2k-diag` must support a stock-baseline run, before the final
Profile 1 link, with a generic debugger probe equivalent to:

- initialize a debugger temporary above the HC11 stack range;
- record each new lowest observed `SP`;
- include `PC` with each new low-water event;
- run the agreed stock regression workload without modifying ROM/DictROM bytes.

This probe is independent of final Profile 1 symbol placement and exists only
to establish stack low-water evidence.

## Resume sequence after the handoff commit

After `trabajos terminados` is verified remotely, **do not rebuild
`as2k-diag` as a normal first step**. The emulator build and its v1
instrumentation are deliverables of the other worker.

Use the already prepared diagnostic emulator in this order:

1. **Run the HC11 relocatable preflight in `SamDelorean/AS2K-V3.14.x`.**
   - execute `sh tools/validate_profile1_debugger_hc11.sh`;
   - record the exact `.p1always_text` size;
   - confirm `.p1iram_bss == 0` and `.p1dbg_bss == 0`;
   - preserve the required-symbol evidence.

2. **Measure stock stack low-water with the existing `as2k-diag` build.**
   - use the v1 stack instrumentation / generic pre-placement probe;
   - capture lowest `SP` and corresponding `PC` evidence;
   - do not select an IRAM interval from assumption or synthetic host-test data.

3. **Authorize one executable IRAM interval.**
   - combine measured stack headroom with the existing ownership/reference
     evidence;
   - record the exact verified-free interval.

4. **Generate the final candidate linker script and link once.**
   - use `tools/render_profile1_debugger_linker.py`;
   - place AppROM only in CPU `0x4000-0x7FFF`;
   - place `.p1always_text` only inside the verified HC11 internal-RAM interval;
   - produce and preserve the linked `nm` map.

5. **Generate and run the G2.7 debugger script on the existing diagnostic build.**
   - use `tools/render_profile1_debugger_mame_cmd.py`;
   - exercise stack low-water / optional stack floor;
   - hit the expected Profile 1/Debugger entry points;
   - fail on `P1_RAMWrite8` execution;
   - optionally watch the explicitly selected ERAM probe interval for writes;
   - capture trace, `logerror` and machine-readable run evidence.

6. **Close G2.7 only from recorded evidence.**
   Required dynamic evidence is:
   - exact `.p1always_text` size;
   - measured stack low-water/headroom;
   - justified executable IRAM placement;
   - successful final link;
   - MAME dynamic run with no prohibited write/stack-floor failures.

Recompile `as2k-diag` only if a concrete failure proves that the delivered
instrumentation is defective or lacks a requirement already present in this
contract.

No G2.8 work is authorized by this document.

## Commander economy rule

The diagnostic build and instrumentation smoke belong to the T160
reimplantation worker. Profile 1 should begin with the HC11 preflight, then use
that existing build for one stock stack-measurement run, one final Profile 1
link and one focused dynamic matrix. Rebuild or rerun only when recorded
evidence identifies a concrete defect or change to test.

Static host work remains outside Commander whenever possible.
