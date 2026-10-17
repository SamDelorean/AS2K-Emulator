#!/usr/bin/env bash
# Read-only G4 compiler failure evidence export. NEVER compile anything.
set -Eeuo pipefail
umask 077
D=/home/spc/Projects/alphasmart/as2k-surface-cross
RUNSTATUS="$D/preflight-g4-v2-20261017.status"
DEST=googledrive:AS2K_TEMP/surface-rt/results/vontar-36996b9/preflight-g4-v2/diagnostics
[ -f "$RUNSTATUS" ] || { echo 'BLOCKED: G4 v2 status missing'; exit 2; }
grep -Fxq 'STATUS=BLOCKED' "$RUNSTATUS" || { echo 'BLOCKED: G4 v2 not blocked'; exit 2; }
grep -Fxq 'STEP=G4_SENTINEL_COMPILE' "$RUNSTATUS" || { echo 'BLOCKED: unexpected G4 phase'; exit 2; }
STAGE=$(sed -n 's/^STAGE=//p' "$RUNSTATUS")
case "$STAGE" in "$D"/preflight-g4-v2.*) ;; *) echo 'BLOCKED: stage outside approved isolated root'; exit 2;; esac
[ -d "$STAGE" ] && [ ! -L "$STAGE" ] || { echo 'BLOCKED: invalid stage'; exit 2; }
for name in bx_file.compiler.log bx_file.argv bx_file.make-dry-run.txt; do
  [ -f "$STAGE/$name" ] && [ ! -L "$STAGE/$name" ] || { echo "BLOCKED: missing $name"; exit 2; }
done
rclone mkdir "$DEST"
for name in bx_file.compiler.log bx_file.argv bx_file.make-dry-run.txt; do
  rclone copyto "$STAGE/$name" "$DEST/$name"
done
printf 'STATUS=PASS\nACTION=G4_V2_READ_ONLY_EVIDENCE_EXPORT\nSTAGE=%s\nNO_COMPILATION=1\n' "$STAGE" > "$D/g4-v2-evidence-export.status"
rclone copyto "$D/g4-v2-evidence-export.status" "$DEST/export.status"
echo 'PASS: compiler stderr, effective argv and dry-run extracted without compilation'
