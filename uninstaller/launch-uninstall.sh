#!/bin/bash
set -euo pipefail
# Run from a private root-owned copy so removing the app cannot interrupt cleanup.
[[ "$EUID" == 0 ]] || exit 1
source_dir=$(cd "$(dirname "$0")" && pwd)
staging=$(/usr/bin/mktemp -d /private/tmp/hush-uninstall.XXXXXXXX)
trap '/bin/rm -rf "$staging"' EXIT
/bin/cp "$source_dir/RestoreAudio" "$source_dir/uninstall.sh" "$staging/"
/bin/chmod 700 "$staging/RestoreAudio" "$staging/uninstall.sh"
log=$(/usr/bin/mktemp /private/tmp/hush-uninstall-log.XXXXXXXX)
/bin/bash "$staging/uninstall.sh" "$@" > "$log" 2>&1
