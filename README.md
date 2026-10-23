# LTRFNet

A menu bar app that joins this Mac to a [Nebula](https://github.com/slackhq/nebula) mesh. It gets its 8-hour host
certificate from a signing service (the CA) with your Azure CLI login, and renews it.

## Build

Open `LTRFNet.xcodeproj` in Xcode and run, or:

```sh
xcodebuild -project LTRFNet.xcodeproj -scheme LTRFNet -derivedDataPath build -allowProvisioningUpdates build
open build/Build/Products/Debug/LTRFNet.app
```

The build phase "Fetch Nebula" runs `scripts/fetch-nebula.sh`, which downloads the pinned Nebula release into `Vendor/`.
To update Nebula, change `version` and `sha256` in that script. `swift scripts/make-icons.swift` draws the icons.

Signing needs an Apple Development certificate (a free Personal Team is sufficient). Set `DEVELOPMENT_TEAM` in the
project to your team.

## Use

1. Run `az login` with an account that the CA accepts.
2. Menu bar → **Settings…**, fill in all fields and save.
3. Menu bar → **Enabled**. The first time, approve LTRFNet in System Settings → Login Items → Allow in the Background.

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
| Key pair, certificates, `config.yml`, `resolver`, `domain` | `/Users/Shared/ltrfnet/` (0700) | the app writes, root reads |
| Nebula | daemon `se.ltrf.ltrfnet.nebula` (`Contents/MacOS/nebula`) | root, from boot |
| Resolver and reload | daemon `se.ltrf.ltrfnet.reload`: on each file change, copies `resolver` to `/etc/resolver/<domain>` and sends SIGHUP to Nebula | root |

- The app registers both daemons with `SMAppService` when you enable it and unregisters them when you disable it.
- The app opens at login. Every 30 minutes it renews the certificate when 4 hours or less are left.
- The private key is yours, not root's: a process that runs as you could already get a certificate with your `az`
  login.
- The reload daemon accepts only a `*.internal` domain without `/`, so a process that runs as you cannot redirect
  other domains.
