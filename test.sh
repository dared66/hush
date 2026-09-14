#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build
xcrun clang -fobjc-arc -O1 -g -Wall -Wextra -Werror \
  -fsanitize=address,undefined -mmacosx-version-min=14.4 -framework Foundation \
  src/tests.m -o build/routing-tests
./build/routing-tests
# Exercise the built HAL factory without loading it into the system audio service.
if [[ ! -f build/HushAudio.driver/Contents/MacOS/HushAudio ]]; then
  zsh scripts/build-driver.sh
fi
xcrun clang++ -std=c++17 -framework CoreAudio -framework CoreFoundation \
  src/driver-tests.cpp -o build/driver-tests
./build/driver-tests "$PWD/build/HushAudio.driver/Contents/MacOS/HushAudio"
