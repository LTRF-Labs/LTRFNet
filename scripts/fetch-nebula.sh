#!/usr/bin/env bash
# Downloads the pinned Nebula release into Vendor/, which Xcode copies into the app and signs.
set -euo pipefail

version=1.11.2
sha256=ae23ebd29e570d72f28d71e608261d454fb87b1a19b4ca21c2aa26bb4698da88

vendor="$(cd "$(dirname "$0")/.." && pwd)/Vendor"
[[ -x "$vendor/nebula" && "$(cat "$vendor/VERSION" 2>/dev/null)" == "$version" ]] && exit 0
mkdir -p "$vendor"
zip="$(mktemp)"
curl -fsSL -o "$zip" "https://github.com/slackhq/nebula/releases/download/v$version/nebula-darwin.zip"
echo "$sha256  $zip" | shasum -a 256 -c -
unzip -oq "$zip" nebula nebula-cert -d "$vendor"
rm "$zip"
echo "$version" >"$vendor/VERSION"
