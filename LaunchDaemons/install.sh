#!/bin/sh
# Installs the LTRFNet launch daemons, or removes them with "uninstall". The app runs it as root after one password
# prompt. Nebula is copied out of the app bundle, so a process that runs as the user cannot replace what root runs.
set -eu

dir="/Library/Application Support/LTRFNet"
labels="se.ltrf.ltrfnet.nebula se.ltrf.ltrfnet.reload"

for label in $labels; do launchctl bootout "system/$label" 2>/dev/null || true; done

if [ "${1:-}" = uninstall ]; then
  d=$(cat /Users/Shared/ltrfnet/domain 2>/dev/null || true)
  case "$d" in */*) ;; *.internal) rm -f "/etc/resolver/$d" ;; esac
  for label in $labels; do rm -f "/Library/LaunchDaemons/$label.plist"; done
  rm -rf "$dir"
  exit 0
fi

here="$(dirname "$0")"
install -d -o root -g wheel -m 755 "$dir"
install -o root -g wheel -m 755 "$here/../MacOS/nebula" "$dir/nebula"
for label in $labels; do
  install -o root -g wheel -m 644 "$here/$label.plist" "/Library/LaunchDaemons/$label.plist"
  launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
done
