#!/bin/zsh
set -euo pipefail
label=local.hush.Hush
domain="gui/$(id -u)"
case "${1:-}" in
  status) launchctl list "$label" ;;
  disable) launchctl bootout "$domain/$label" ;;
  enable) launchctl bootstrap "$domain" "$HOME/Library/LaunchAgents/$label.plist" ;;
  *) print -u2 'Usage: zsh scripts/login.sh status|enable|disable'; exit 2 ;;
esac
