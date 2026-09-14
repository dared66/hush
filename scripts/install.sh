#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
zsh scripts/package-installer.sh
version=$(plutil -extract CFBundleShortVersionString raw Info.plist)
open "dist/Hush-$version.pkg"
