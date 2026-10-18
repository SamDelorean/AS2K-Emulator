# AS2K Stable Public — VONTAR full installation snapshot

**Snapshot date:** 2026-10-18  
**Reference system:** VONTAR X3, Armbian AArch64, installed under `/usr/local`  
**Public release branch:** `release/vontar-stable-public-20261018`  
**Source baseline:** `SamDelorean/AS2K-Emulator@36996b91053969661371dc067d49026fab367a47`  
**MAME donor:** `SamDelorean/mame-as3k@1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`

## Meaning of this release

This branch preserves the **actual VONTAR Stable application with its accessories**. The baseline is not the preliminary `packaging/as2k-launcher.sh` shell frontend and is not the Surface RT port. The reference VONTAR installation uses a standalone GTK session manager **in addition to** the MAME core and base GTK UI. The session manager was not present in the original pinned source tree and has now been incorporated without changing its bytes.

The VONTAR installation was used successfully for human testing; the user explicitly elected to freeze this as the current **Stable Public** reference. This is a **public source snapshot and build/install source**. It is not an assertion that a downloadable precompiled binary or formal GitHub Release has been published. The public branch is intentionally frozen; improvements must be developed elsewhere and validated before promotion.

## Installed component identity (reference VONTAR)

| Installed path relative to `/usr/local` | Purpose | Verified installed SHA-256 |
| --- | --- | --- |
| `bin/as2k` | Canonical session launcher (85 bytes) | `bc7c2670c82c53f10275a0ea8d83b09f9696930dee72d897e4e7de8f301720a8` |
| `libexec/as2k/frontend/as2k_session.py` | Session, ROM/DictROM/bootstrap and integrated display manager (23,071 bytes) | `57d0dd376cb8809858d19179373c8d813ff5eb7be9d0a103d6270904e703bf0f` |
| `libexec/as2k/frontend/as2k_ui.py` | Core GTK menus, LCD, keyboard, Send/Print/IR/media (34,704 bytes) | `ff8be74da550720c6e35c25df974d65161ef2b939a978bf0da7763f78b76051a` |
| `libexec/as2k/frontend/as2k_pcl_to_pdf.py` | Print output conversion helper | `ec966d0a4d20e4e4695cec58ae2b2b29b28ef15e2d8bd3be38c47fa95c17df6a` |
| `share/applications/as2k.desktop` | Desktop/application-menu integration | `eb993791ad455265b3c9c57ef0616f051d0e3fa8c1595b8f6b0ce381e2a535a2` |
| `libexec/as2k/as2k-bin` | Stable MAME reduced core for VONTAR AArch64 (66,150,416 bytes) | `099a1113f8c148448e47d0fb86c37e8644c6fbdb3cea261da1fff026e54d2469` |

The installed `frontend/alphasmart_2000_shortcuts.txt` is included as an accessory in source/install packaging, but its hash was **not independently measured** in the VONTAR installed-file audit. The AArch64 core hash identifies the reference binary only; cross-architecture builds naturally differ.

## Complete source-accessory inventory

This release includes:

- Reduced AS2K stable MAME driver, HC11 build patchers, pinned donor/build procedure and source validation gates.
- **Exact VONTAR `as2k_session.py`**, preserved byte-for-byte and called by the canonical 85-byte `as2k` launcher.
- GTK front-end with AlphaSmart LCD, virtual and physical keyboard, file selection, context menus, screenshot PNG and video recording MP4/H.264 (FFmpeg when installed).
- ROM/DictROM and optional bootstrap selection, normal/DictROM start modes, reset, payload selector (Workbench controls are retained because this snapshot reproduces VONTAR).
- Integrated one-window LCD mode using `SDL_VIDEODRIVER=dummy`, with selectable SDL two-window fallback.
- PC Send text, printing via CUPS/PCL-to-PDF helper, and IR activity indication.
- Local keyboard-shortcuts documentation, launcher, `.desktop` integration, install/uninstall scripts, and bundled source documentation and test scripts.
- Per-user XDG configuration and paths for NVRAM, state, print/output and runtime IPC, without copying any such user data.

**External runtime dependencies** include GTK3/PyGObject, SDL2/SDL2_ttf, X11 for the optional SDL mode, FFmpeg for recordings, and CUPS/filter utilities for printing. Functions dependent on external services remain subject to those services being installed and configured.

## Build and install on VONTAR

The public source branch is the intended source checkout:

```sh
git clone --branch release/vontar-stable-public-20261018 \
  https://github.com/SamDelorean/AS2K-Emulator.git
cd AS2K-Emulator
sh install-as2k-vontar.sh --check
sh install-as2k-vontar.sh --install
```

The VONTAR installer checks AArch64, supported Debian/Armbian, Git cleanliness, the pinned MAME donor and the reduced build; it can install system packages and build tools when invoked. It now installs both the base UI and the exact session manager. The canonical installation prefix is **`/usr/local`**. The launcher uses `/usr/local/libexec/as2k/frontend/as2k_session.py` and starts the installed reduced core; it does not depend on the source working directory.

**Do not run the installer merely to inspect the release.** The commands above are installation instructions for an explicitly chosen target system, not an action performed on the user's functioning VONTAR installation during publication.

## ROM and user-data boundary

No ROMs or private payloads are included. Each user must supply their own legally obtained firmware, DictROM and any LCD-controller ROMs required by their MAME version; for example MAME may look for `ks0066/ks0066_f05.bin` within the configured `-rompath`.

The user-specific reference VONTAR session happened to have `boot_mode=dictrom`, `bootstrap_enabled=0`, `display_mode=integrated`, and `payload_name=STOCK`. Those are **private runtime preferences**, not files or mandated defaults distributed with the release. A fresh installation initially selects normal boot unless the user changes it; the session manager saves choices locally.

**Never publish** firmware, DictROM images, optional proprietary bootstrap/payload binaries, NVRAM/RAM data, save states, print captures, PC Send documents, diagnostic traces, credentials, private machine IDs or personal file paths. `as2k-diag` is separate and private; it is not part of this stable source release.

## Scope and known qualifications

The user approved this baseline as currently functional, but that is not a claim that every peripheral regression, NVRAM persistence across abrupt shutdown, or all firmware variants have passed a new release test. In particular, previous investigation recorded an **open NVRAM persistence concern** when the MAME process is forcibly terminated; do not claim that the issue has been resolved without a controlled regression.

The public branch includes the necessary source and accessory files, but **no public precompiled AArch64 binary is attached**. A formal binary release requires the dependency and license/provenance gate described in `docs/LEGAL_SCOPE.md`, corresponding sources, and release regression evidence.

## Change control

This branch is the immutable reference named **AS2K Stable Public — VONTAR full**. Preserve this installed baseline, its filenames and session behavior. Use separate development branches for later enhancements, including Surface RT port corrections. Do not replace this reference with `as2k-diag`, a MAME generic UI or the preliminary direct-shell launcher.
