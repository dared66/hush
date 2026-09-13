#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
for script in build.sh test.sh scripts/*.sh; do zsh -n "$script"; done
plutil -lint Info.plist
zsh build.sh
zsh test.sh
stage=$(mktemp -d -t hush-check)
trap 'rm -rf "$stage"' EXIT
app_dir="$stage/Applications with spaces & symbols"
HUSH_INSTALL_DIR="$app_dir" zsh scripts/install.sh
HUSH_INSTALL_DIR="$app_dir" zsh scripts/login.sh preview > "$stage/login.plist"
actual=$(plutil -extract ProgramArguments.2 raw "$stage/login.plist")
[[ "$actual" == "$app_dir/Hush.app" ]]
[[ $(plutil -extract RunAtLoad raw "$stage/login.plist") == true ]]
# A second install must refuse to overwrite an existing app.
if HUSH_INSTALL_DIR="$app_dir" zsh scripts/install.sh 2>/dev/null; then
  print -u2 'FAIL: installer overwrote an existing app'; exit 1
fi
print 'PASS: build, audio tests, isolated install, escaped login path, overwrite protection.'
