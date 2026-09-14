#!/bin/bash
set -euo pipefail
resource_dir=$(cd "$(dirname "$0")" && pwd)
purge=0
dry_run=0
for arg in "$@"; do
  case "$arg" in
    --purge) purge=1 ;;
    --dry-run) dry_run=1 ;;
    *) echo 'Usage: uninstall.sh [--purge] [--dry-run]' >&2; exit 2 ;;
  esac
done
console_user=$(/usr/bin/stat -f %Su /dev/console)
if [[ "$console_user" == root || "$console_user" == loginwindow ]]; then
  echo 'Log in to your Mac before uninstalling Hush.' >&2; exit 1
fi
console_uid=$(/usr/bin/id -u "$console_user")
user_home=$(/usr/bin/dscl . -read "/Users/$console_user" NFSHomeDirectory | /usr/bin/cut -d ' ' -f 2-)
[[ "$user_home" == /* && "$user_home" != / && -d "$user_home" ]] || exit 1
helper="$resource_dir/RestoreAudio"
[[ -x "$helper" ]] || { echo 'Audio restoration helper is missing.' >&2; exit 1; }
audio_command=("$helper")
if [[ "$EUID" == 0 ]]; then
  audio_command=(/bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" "$helper")
fi
"${audio_command[@]}" --plan
if [[ "$dry_run" == 1 ]]; then
  echo 'Would stop Hush and its login agents, restore physical audio, remove the app and driver, and restart Core Audio.'
  if [[ "$purge" == 1 ]]; then echo 'Would also remove this user’s Hush preferences and legacy backups.'; fi
  exit 0
fi
[[ "$EUID" == 0 ]] || { echo 'Administrator access is required. Open Hush and choose Uninstall Hush.' >&2; exit 1; }
# Stop routing before changing defaults so the agent cannot select the virtual device again.
agent="$user_home/Library/LaunchAgents/local.hush.Hush.plist"
was_loaded=0
if /bin/launchctl list local.hush.Hush >/dev/null 2>&1 || /bin/launchctl print "gui/$console_uid/local.hush.Hush" >/dev/null 2>&1; then
  was_loaded=1
  /bin/launchctl bootout "gui/$console_uid/local.hush.Hush"
fi
for label in local.krupa.Hush; do
  if /bin/launchctl print "gui/$console_uid/$label" >/dev/null 2>&1; then /bin/launchctl bootout "gui/$console_uid/$label"; fi
done
for name in Hush MonitorVolume; do
  for pid in $(/usr/bin/pgrep -u "$console_uid" -x "$name" || true); do
    executable=$(/bin/ps -p "$pid" -o command=)
    case "$executable" in
      /Applications/Hush.app/Contents/MacOS/Hush*|"$user_home/Applications/Hush.app/Contents/MacOS/MonitorVolume") /bin/kill -TERM "$pid" ;;
    esac
  done
done
if ! "${audio_command[@]}" --apply; then
  if [[ "$was_loaded" == 1 && -f "$agent" ]]; then /bin/launchctl bootstrap "gui/$console_uid" "$agent" || true; fi
  exit 1
fi
# Remove only Hush-owned, fixed installation paths. Keep user data unless explicitly requested.
/bin/rm -f "$agent" "$user_home/Library/LaunchAgents/local.krupa.Hush.plist"
/bin/rm -rf /Applications/Hush.app /Library/Audio/Plug-Ins/HAL/HushAudio.driver
if [[ "$purge" == 1 ]]; then
  for domain in local.hush.Hush local.krupa.MonitorVolume; do
    /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" /usr/bin/defaults delete "$domain" >/dev/null 2>&1 || true
  done
  /bin/rm -rf "$user_home/Library/Application Support/Hush"
fi
/usr/sbin/pkgutil --forget local.hush.installer >/dev/null 2>&1 || true
# The audio service releases the driver only after a restart; audio pauses briefly.
if ! /usr/bin/killall coreaudiod; then
  echo 'Hush was removed. Restart your Mac to unload the audio driver.'
else
  echo 'Hush was removed and Core Audio was restarted.'
fi
/bin/rm -f '/Applications/Uninstall Hush.command'
/bin/rm -rf '/Library/Application Support/Hush/Uninstaller'
echo 'Your monitor now uses its original hardware volume. Hush’s software attenuation is no longer applied.'
if [[ "$purge" == 0 ]]; then echo 'Hush preferences and legacy backups were kept.'; fi
