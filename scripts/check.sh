#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
for script in build.sh test.sh scripts/*.sh; do zsh -n "$script"; done
bash -n installer/scripts/postinstall
for script in uninstaller/*.sh; do bash -n "$script"; done
plutil -lint Info.plist installer/local.hush.Hush.plist driver/ProxyAudio/Info.plist
zsh build.sh
zsh test.sh
