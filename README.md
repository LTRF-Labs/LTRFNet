# LTRFNet

A menu bar app that joins this Mac to a [Nebula](https://github.com/slackhq/nebula) mesh. It gets its 8-hour host
certificate from a signing service (the CA) with your Azure CLI login, and renews it.

## Install

```sh
curl -fsSL https://github.com/LTRF-Labs/LTRFNet/releases/latest/download/LTRFNet.zip | ditto -x -k - /Applications
```

The app has an ad-hoc signature, not an Apple one. A download with `curl` gets no quarantine attribute, so macOS opens
the app. If you download the zip with a browser, run `xattr -dr com.apple.quarantine /Applications/LTRFNet.app` once.

To make a release, push a tag such as `v0.2.0`. The workflow `.github/workflows/release.yml` builds the app and attaches
`LTRFNet.zip` to the release.

## Build

Open `LTRFNet.xcodeproj` in Xcode and run, or:

```sh
xcodebuild -project LTRFNet.xcodeproj -scheme LTRFNet -derivedDataPath build build
open build/Build/Products/Debug/LTRFNet.app
```

The build phase "Fetch Nebula" runs `scripts/fetch-nebula.sh`, which downloads the pinned Nebula release into `Vendor/`.
To update Nebula, change `version` and `sha256` in that script. `swift scripts/make-icons.swift` draws the icons.

The app has an ad-hoc signature, so you need no Apple account or certificate.

## Use

1. Run `az login` with an account that the CA accepts.
2. Menu bar → **Settings…**, fill in all fields and save.
3. Menu bar → **Install…** and enter your admin password. Do this again when the menu shows **Install…**, after an
   update or a change to Settings.
4. Menu bar → **Enabled**.

**Uninstall…** removes the daemons, the copy of Nebula and the resolver.

The menu shows until when the certificate is valid, or the error.

## Settings

`~/.config/ltrfnet/config.json`:

| Key | Example | Use |
|---|---|---|
| `nameserver` | `10.250.0.1` | DNS server on the overlay |
| `dnsDomain` | `corp.internal` | Domain that resolves through `nameserver`; it must end in `.internal` |
| `lighthouse` | `10.250.0.1` | Overlay address of the lighthouse and relay |
| `hubEndpoint` | `hub.example.com:4242` | Public address of the lighthouse |
| `caURL` | `https://ca.example.com` | Signing service |
| `caAppIDURI` | `api://<app id>` | Entra resource for the `az` token |

## The CA

`POST {caURL}/sign` with `Authorization: Bearer <az account get-access-token --resource {caAppIDURI}>` and the body
`{"public_key": "<host.pub>"}`. A `200` answer contains at least `{"ca": "<PEM>", "certificate": "<PEM>"}`.

## Design

| What | Where | Who |
|---|---|---|
| Settings | `~/.config/ltrfnet/config.json` | the app |
| Key pair, certificates, `nameserver`, `domain`, `enabled` | `~/Library/Application Support/LTRFNet/` (0700) | the app writes |
| Nebula and its `config.yml` | `/Library/Application Support/LTRFNet/` | root; written only by **Install…** |
| Nebula daemon | `se.ltrf.ltrfnet.nebula` runs Nebula while `enabled` exists | root |
| Resolver, reload and stop | daemon `se.ltrf.ltrfnet.reload`: on each file change, writes `/etc/resolver/<domain>`, then sends SIGHUP to Nebula, or SIGTERM when `enabled` is gone | root |

- **Install…** runs `install.sh` from the app bundle as root (one password prompt). It installs Nebula, its
  `config.yml` (from the app, through stdin) and the daemons in `/Library`. Root owns them, so a process that runs as
  you cannot change what root runs. After a change to Settings, the menu shows **Install…** again. The daemons need no
  team signature, so the app needs no paid Apple Developer membership.
- The toggle makes or removes `enabled`, so it needs no root.
- The app opens at login. Every 30 minutes it renews the certificate when 4 hours or less are left.
- The private key is yours, not root's: a process that runs as you could already get a certificate with your `az`
  login.
- The reload daemon reads only the first line of `domain` and `nameserver`. It accepts only a lowercase `*.internal`
  domain and an IP address, and writes the resolver itself, so a process that runs as you cannot redirect other
  domains or make root copy another file.
- A process that runs as you can still replace the certificates and the key. That changes only which mesh Nebula
  joins, not what root runs.
