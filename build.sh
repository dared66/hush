#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app="build/Hush.app"
# Recreate generated output so renamed executables cannot remain in the bundle.
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  -mmacosx-version-min=14.4 -framework Cocoa -framework CoreAudio -framework Security \
  src/main.m -o "$app/Contents/MacOS/Hush"
cp Info.plist "$app/Contents/Info.plist"
mkdir -p "$app/Contents/Resources"
cp assets/Hush.icns "$app/Contents/Resources/Hush.icns"
cp installer/local.hush.Hush.plist "$app/Contents/Resources/"
mkdir -p "$app/Contents/Resources/Uninstaller"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Werror -mmacosx-version-min=14.4 -framework Foundation -framework CoreAudio uninstaller/RestoreAudio.m -o "$app/Contents/Resources/Uninstaller/RestoreAudio"
codesign --force --sign - "$app/Contents/Resources/Uninstaller/RestoreAudio"
cp uninstaller/{uninstall.sh,launch-uninstall.sh} "$app/Contents/Resources/Uninstaller/"
codesign --force --sign - --identifier local.hush.Hush "$app"
codesign --verify --strict "$app"
plutil -lint "$app/Contents/Info.plist"

zsh scripts/build-driver.sh
