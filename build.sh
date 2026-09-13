#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app="build/Hush.app"
# Recreate generated output so renamed executables cannot remain in the bundle.
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  -mmacosx-version-min=14.4 -framework Cocoa -framework CoreAudio \
  src/main.m src/AudioRender.m -o "$app/Contents/MacOS/Hush"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - --identifier local.hush.Hush "$app"
codesign --verify --strict "$app"
plutil -lint "$app/Contents/Info.plist"
