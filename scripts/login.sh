#!/bin/zsh
set -euo pipefail
mode="${1:-}"
if (( $# != 1 )) || [[ "$mode" != enable && "$mode" != disable && "$mode" != status && "$mode" != preview ]]; then
  print -u2 'Usage: zsh scripts/login.sh enable|disable|status|preview'
  exit 2
fi
label=local.hush.Hush
app="${HUSH_INSTALL_DIR:-$HOME/Applications}/Hush.app"
agent_dir="$HOME/Library/LaunchAgents"
agent="$agent_dir/$label.plist"
domain="gui/$(id -u)"
if [[ "$mode" == status ]]; then
  launchctl list "$label"
  exit
fi
if [[ "$mode" == disable ]]; then
  if launchctl list "$label" >/dev/null 2>&1; then launchctl bootout "$domain/$label"; fi
  if [[ -f "$agent" ]]; then
    mkdir -p "$HOME/.Trash"
    mv "$agent" "$HOME/.Trash/$label-$(date +%s).plist"
  fi
  print 'Automatic login launch disabled. Hush can still be opened manually.'
  exit
fi
[[ "$app" == /* && -d "$app" ]] || { print -u2 "Install Hush first: $app"; exit 1; }
tmpfile=$(mktemp -t hush-login)
trap 'rm -f "$tmpfile"' EXIT
plutil -create xml1 "$tmpfile"
plutil -insert Label -string "$label" "$tmpfile"
plutil -insert ProgramArguments -json '[]' "$tmpfile"
plutil -insert ProgramArguments.0 -string /usr/bin/open "$tmpfile"
plutil -insert ProgramArguments.1 -string -g "$tmpfile"
plutil -insert ProgramArguments.2 -string "$app" "$tmpfile"
plutil -insert RunAtLoad -bool YES "$tmpfile"
plutil -insert LimitLoadToSessionType -string Aqua "$tmpfile"
plutil -lint "$tmpfile" >/dev/null
if [[ "$mode" == preview ]]; then cat "$tmpfile"; exit; fi
mkdir -p "$agent_dir"
if launchctl list "$label" >/dev/null 2>&1; then launchctl bootout "$domain/$label"; fi
cp "$tmpfile" "$agent"
launchctl bootstrap "$domain" "$agent"
print 'Hush will open when you log in. It is also being opened now.'
