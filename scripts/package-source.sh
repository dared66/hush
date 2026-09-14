#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p dist
version=$(plutil -extract CFBundleShortVersionString raw Info.plist)
# Explicit allowlist: never include local build outputs, Git history, or parent files.
COPYFILE_DISABLE=1 tar --exclude=.DS_Store --exclude='._*' -czf "dist/hush-$version-source.tar.gz" \
  README.md LICENSE THIRD_PARTY_NOTICES.md CONTRIBUTING.md SECURITY.md CHANGELOG.md Info.plist \
  .gitignore build.sh test.sh src scripts docs .github driver installer uninstaller assets
print "Created dist/hush-$version-source.tar.gz"
