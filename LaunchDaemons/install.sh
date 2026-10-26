#!/bin/sh
# Installs the LTRFNet launch daemons, or removes them with "uninstall". The app runs it as root after one password
# prompt: `install.sh install|uninstall <user folder>`, with Nebula's config.yml on stdin for install.
# Root owns Nebula and its config, so a process that runs as the user cannot change what root runs. Root reads no file
# from the user folder here.
set -eu

root="/Library/Application Support/LTRFNet"
user="$2"
labels="se.ltrf.ltrfnet.nebula se.ltrf.ltrfnet.reload"

# Only ~/Library/Application Support/LTRFNet, with characters that are safe in sed, XML and sh.
case "$user" in
  *[!A-Za-z0-9._/\ -]*) echo "Refused folder: $user" >&2; exit 1 ;;
  /Users/*/Library/Application\ Support/LTRFNet) ;;
  *) echo "Refused folder: $user" >&2; exit 1 ;;
esac

for label in $labels; do launchctl bootout "system/$label" 2>/dev/null || true; done

if [ "$1" = uninstall ]; then
  d=$(head -n 1 "$user/domain" 2>/dev/null || true)
  case "$d" in *[!a-z0-9.-]*|"") ;; *.internal) rm -f "/etc/resolver/$d" ;; esac
  for label in $labels; do rm -f "/Library/LaunchDaemons/$label.plist"; done
  rm -rf "$root"
  exit 0
fi

here="$(dirname "$0")"
umask 022
install -d -o root -g wheel -m 755 "$root"
install -o root -g wheel -m 755 "$here/../MacOS/nebula" "$root/nebula"
cat >"$root/config.yml"
for label in $labels; do
  sed "s#__USER_DIR__#$user#g" "$here/$label.plist" >"/Library/LaunchDaemons/$label.plist"
  launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
done
