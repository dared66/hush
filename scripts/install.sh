#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if (( $# > 1 )) || [[ ${1:-} != "" && ${1:-} != --login ]]; then
  print -u2 'Usage: zsh scripts/install.sh [--login]'
  exit 2
fi
app_dir="${HUSH_INSTALL_DIR:-$HOME/Applications}"
[[ "$app_dir" == /* ]] || { print -u2 'HUSH_INSTALL_DIR must be absolute'; exit 2; }
if [[ -e "$app_dir/Hush.app" ]]; then
  print -u2 "An app already exists at $app_dir/Hush.app. Quit it and move it to Trash before installing."
  exit 1
fi
zsh build.sh
mkdir -p "$app_dir"
ditto build/Hush.app "$app_dir/Hush.app"
codesign --verify --strict "$app_dir/Hush.app"
if [[ ${1:-} == --login ]]; then
  HUSH_INSTALL_DIR="$app_dir" zsh scripts/login.sh enable
fi
print "Installed $app_dir/Hush.app"
print 'Open Hush, then allow System Audio Recording Only when macOS asks.'
