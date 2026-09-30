#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build
xcrun clang++ -std=c++17 -fblocks -O1 -g -DDEBUG=0 -Wno-deprecated-declarations \
  -fsanitize=address,undefined -mmacosx-version-min=14.4 \
  -framework CoreAudio -framework CoreFoundation -framework CoreServices \
  -framework IOKit -framework ApplicationServices \
  -Idriver/ProxyAudio -Idriver/ProxyAudio/PublicUtility -Idriver/shared \
  src/audio-stream-tests.cpp driver/ProxyAudio/*.cpp \
  driver/ProxyAudio/PublicUtility/*.cpp driver/shared/*.cpp -o build/audio-stream-tests
./build/audio-stream-tests
