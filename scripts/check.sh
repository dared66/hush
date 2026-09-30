#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
for script in build.sh test.sh scripts/*.sh; do zsh -n "$script"; done
for script in installer/scripts/*; do bash -n "$script"; done
for script in uninstaller/*.sh; do bash -n "$script"; done
plutil -lint Info.plist installer/local.hush.Hush.plist driver/ProxyAudio/Info.plist
zsh build.sh
zsh test.sh
