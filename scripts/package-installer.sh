#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
version=$(plutil -extract CFBundleShortVersionString raw Info.plist)
zsh build.sh
rm -rf build/package-root
mkdir -p build/package-root/Applications build/package-root/Library/Audio/Plug-Ins/HAL dist
ditto --norsrc --noextattr --noqtn build/Hush.app build/package-root/Applications/Hush.app
ditto --norsrc --noextattr --noqtn build/HushAudio.driver build/package-root/Library/Audio/Plug-Ins/HAL/HushAudio.driver
pkgbuild --analyze --root build/package-root build/components.plist
plutil -replace 0.BundleIsRelocatable -bool NO build/components.plist
plutil -replace 1.BundleIsRelocatable -bool NO build/components.plist
pkgbuild --root build/package-root --component-plist build/components.plist --scripts installer/scripts --identifier local.hush.installer \
  --version "$version" --install-location / --ownership recommended "dist/Hush-$version.pkg"

zsh scripts/check-package.sh
