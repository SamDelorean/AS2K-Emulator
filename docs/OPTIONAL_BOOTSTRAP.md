# Optional HC11 bootstrap

Stock firmware starts normally when no bootstrap file is supplied.
Firmware ROM and dictionary ROM are external user-provided files.
An optional 1–192 byte HC11 program may be loaded into internal RAM at
address $0040 using the GTK file picker or AS2K_BOOTSTRAP_FILE.
The CPU executes the external program after device reset; HPRIO changes
are executed by the modeled CPU. Removing the program restores stock boot.
The emulator does not contain or distribute any bootstrap program or ROM.

Source reference: SamDelorean/mame-as3k, ae2f3ed97d3230e48fb33386230c27434fa94a25.
This PR-specific revision has not yet passed native compilation and GUI validation.
