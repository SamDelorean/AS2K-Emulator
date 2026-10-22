# Stable reduced code preparation

Status: **R0 static preparation; build validation pending Commander/T160**

## Donor baseline

The initial source donor is:

- repository: `SamDelorean/mame-as3k`
- commit: `5901a4595f12fc5a0080647fac76c41522495dc1`
- path: `src/mame/skeleton/alphasma.cpp`
- blob: `fba7023f37f7a89a00d72601ee39234e6ad80231`
- reason: this revision contains the validated physical-port PC Send implementation and removes the temporary firmware-PC instruction callback used by earlier diagnostic work.

The file is imported unchanged first so its provenance is auditable. Reduction and product changes occur as separate commits.

## Static transformation order

1. **AS2K-only scope**
   - remove AlphaSmart Pro registration/runtime material not required by the AS2K target;
   - retain only shared code actually required by AS2K.

2. **External runtime images**
   - replace the fixed ROM-set dependency with user-mounted external firmware and DictROM image devices;
   - no firmware bytes in Git;
   - accept compatible images independently of v3.1.4;
   - validate size/shape with clear errors rather than silently rewriting files.

3. **Image-selection UX**
   - expose firmware and DictROM through mouse-accessible file selection;
   - remember paths only in local stable configuration outside Git;
   - use v3.1.4 only as the reference regression image.

4. **Boot selector**
   - normal boot remains stock reset;
   - Direct DictROM Bootstrap is a separate emulator action reproducing the ATtiny85 bootstrap preconditions that are required in emulation;
   - selected images remain byte-for-byte unchanged.

5. **Stable host functions**
   - preserve keyboard, 40x4 LCD, sleep/wake, 128 KiB persistent NVRAM and banking;
   - preserve the physical-port PC Send implementation from the donor;
   - integrate stable CUPS/PDF printing;
   - keep load/save/clear NVRAM and save-state operations in stable user space.

6. **No diagnostic contamination**
   - do not import private address probes, private traces or Commander controls into stable;
   - reusable hardware corrections discovered by diagnostic work may be promoted later as separate reviewed commits.

7. **Reduced target closure**
   - derive the minimal dependency closure for a dedicated `as2k` target;
   - do not copy the full MAME tree by default;
   - preserve SPDX/copyright metadata for every imported file.

## Build gate when Commander returns

Before this branch can merge to `main`:

- complete dependency closure;
- build the dedicated reduced target;
- pass `-validate`;
- run normal boot with the external reference firmware;
- verify alternate compatible firmware loading;
- verify LCD/keyboard/banking/NVRAM;
- verify PC Send and printing;
- verify Direct DictROM Bootstrap;
- measure clean/incremental build time and disk usage;
- confirm no proprietary/private material is present.

No cleanup of existing Git repositories is authorized by this preparation branch.


## Static implementation checkpoint — 2026-09-30

The preparation branch now contains code, not only design notes.

### Implemented statically

- AS2K-only machine registration; AlphaSmart Pro ROM registration is excluded from the reduced target.
- Fixed AS2K BIOS/DictROM declarations removed from the driver.
- Mandatory external user-loadable Firmware and DictROM image sockets.
- Firmware loader accepts either a 0x8000 executable image or a 0x81E5 ZPSD-style dump and maps only the first 0x8000 bytes without modifying the source.
- DictROM loader accepts 0x20000 bytes and preserves the eight 0x4000-byte hardware banks.
- Normal reset remains the default boot mode.
- `Direct DictROM bootstrap` is implemented as the documented post-stage-0 machine state, with bus/bank/device state established before PC is committed to 0x4000.
- PC Send remains based on physical port traffic from the validated donor; its stable text output now follows the configured stable output directory instead of the firmware/media path.
- Linux system launcher, application-menu template, installer, uninstaller and static validation gate are present.

### Build-gated / not yet closed

- native C++ compile against the reduced dependency closure;
- MAME `-validate`;
- runtime file-manager behavior for the two mandatory image sockets;
- normal-boot regression with v3.1.4 reference and at least one alternate compatible firmware;
- Direct DictROM bootstrap runtime regression against the known stage-0 contract;
- stable CUPS/PDF print path;
- full reduced dependency closure and build-system finalization;
- installation on T160 and final system/menu acceptance tests.

No item in the second list may be promoted to PASS without T160/Commander evidence.
