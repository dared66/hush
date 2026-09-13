#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build
xcrun clang -fobjc-arc -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter \
  -fsanitize=address,undefined -mmacosx-version-min=14.4 \
  -framework Foundation -framework CoreAudio \
  src/tests.m src/AudioRender.m -o build/audio-tests
./build/audio-tests
