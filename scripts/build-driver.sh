#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
driver=build/HushAudio.driver
rm -rf "$driver"
mkdir -p "$driver/Contents/MacOS" "$driver/Contents/Resources/English.lproj"
xcrun clang++ -std=c++17 -fblocks -O2 -DDEBUG=0 -Wno-deprecated-declarations \
  -arch arm64 -arch x86_64 -mmacosx-version-min=14.4 -bundle -framework CoreAudio -framework CoreFoundation \
  -framework CoreServices -framework IOKit -framework ApplicationServices \
  -Idriver/ProxyAudio -Idriver/ProxyAudio/PublicUtility -Idriver/shared \
  driver/ProxyAudio/*.cpp driver/ProxyAudio/PublicUtility/*.cpp driver/shared/*.cpp \
  -o "$driver/Contents/MacOS/HushAudio"
cp driver/ProxyAudio/Info.plist "$driver/Contents/Info.plist"
for key in CFBundleShortVersionString CFBundleVersion; do
  value=$(plutil -extract "$key" raw Info.plist)
  plutil -replace "$key" -string "$value" "$driver/Contents/Info.plist"
done
cp driver/ProxyAudio/English.lproj/Localizable.strings "$driver/Contents/Resources/English.lproj/Localizable.strings"
cp assets/Hush.icns "$driver/Contents/Resources/DeviceIcon.icns"
codesign --force --sign - "$driver"
codesign --verify --strict "$driver"
