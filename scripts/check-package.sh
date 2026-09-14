#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
version=$(plutil -extract CFBundleShortVersionString raw Info.plist)
package="dist/Hush-$version.pkg"
[[ -f "$package" ]]
validation=$(mktemp -d "${TMPDIR:-/tmp}/hush-package-check.XXXXXXXX")
trap 'rm -rf "$validation"' EXIT
pkgutil --expand-full "$package" "$validation/expanded"
payload="$validation/expanded/Payload"
[[ -d "$payload" ]]
[[ -d "$payload/Applications/Hush.app" ]]
[[ $(ls -A "$payload/Applications" | wc -l | tr -d ' ') == 1 ]]
[[ ! -e "$payload/Applications/Uninstall Hush.command" ]]
[[ ! -e "$payload/Library/Application Support/Hush/Uninstaller" ]]
for bundle in Applications/Hush.app Library/Audio/Plug-Ins/HAL/HushAudio.driver; do
  [[ $(plutil -extract CFBundleShortVersionString raw "$payload/$bundle/Contents/Info.plist") == "$version" ]]
  codesign --verify --deep --strict "$payload/$bundle"
done
resources="$payload/Applications/Hush.app/Contents/Resources"
[[ -f "$resources/Hush.icns" && -x "$resources/Uninstaller/RestoreAudio" ]]
[[ -f "$resources/Uninstaller/launch-uninstall.sh" && -f "$resources/Uninstaller/uninstall.sh" ]]
[[ $(plutil -extract ProgramArguments.1 raw "$resources/local.hush.Hush.plist") == --background ]]
# pkgbuild may encode macOS extended attributes as AppleDouble archive records.
# Check installed files after expansion; archive metadata is not an extra app.
metadata=("$payload"/**/.DS_Store(N) "$payload"/**/._*(N))
[[ ${#metadata} == 0 ]]
print 'PASS: one app, embedded uninstaller, matching versions, silent startup, signatures, and clean package payload.'
