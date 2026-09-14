#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcrun swift -module-cache-path /tmp/hush-swift-module-cache scripts/render-icons.swift assets
for name in Hush; do
  iconset="build/$name.iconset"
  mkdir -p "$iconset"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "assets/$name.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" "assets/$name.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$iconset" -o "assets/$name.icns"
done
