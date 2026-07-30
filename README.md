<p align="center">
  <img src="Resources/graf-banner-slskd.png" alt="deemon" width="">
</p>
<p align="center">
  <a href="https://github.com/slskd/slskd">
    <img src="https://custom-icon-badges.demolab.com/badge/slskd-repo-03a6ff?style=for-the-badge&logoColor=&logo=slskd-color-icon" alt="Deemix Downloader">
  </a>
  <a href="">
    <img src="https://custom-icon-badges.demolab.com/badge/platform-macos-03a6ff?style=for-the-badge&logoColor=&logo=apple" alt="">

# slskdbar

slskdbar is a lightweight native macOS menu bar companion for
[slskd](https://github.com/slskd/slskd). It makes the Soulseek connection state
visible and puts the controls you use most within one click.

## Features

- Shows connected, connecting, disconnected, and unavailable states with
  distinct icons.
- Connects to slskd's application event hub, so status changes are pushed
  without continuous polling.
- Connects and disconnects Soulseek from the menu bar.
- Shows current download and upload activity when the menu is open.
- Optionally shows active transfer counts beside the menu bar icon.
- Clears completed downloads, uploads, or both.
- Opens the slskd dashboard, downloads, configuration, logs, and data folders.
- Detects and launches Nicotine+ and SoulseekQt when installed, with official
  download links when they are not.
- Supports connection-change notifications, launch at login, custom locations,
  and custom status icons.

The transfer-count display is disabled by default. With it disabled, slskdbar
maintains one event connection and does no background polling.

## Requirements

- macOS 14 or later
- Swift 6.2 or later when building from source
- A running slskd instance with its web API enabled
- A slskd API key in `slskd.yml`

slskdbar defaults to `http://localhost:5030` and reads the first key under
`web.authentication.api_keys` from the configured runtime file. The API key is
read only when a request or event connection needs it and is not copied into
macOS preferences.

## Install from a DMG

Download `slskdbar-<version>.dmg` from the Releases page, open it, and drag
`slskdbar.app` to the Applications shortcut.

Release builds must be signed with a Developer ID certificate and notarized to
open normally on other Macs. An ad-hoc signed development DMG can still be used
for local testing, but macOS may show a Gatekeeper warning when it is downloaded.

## Build from source

```sh
cd slskdbar
bash scripts/build-app.sh
```

Clone or download this repository first. The app is created at
`dist/slskdbar.app`. Move it to `/Applications`, then open it. The development
build is ad-hoc signed; a downloaded release should be signed and notarized
before broad distribution.

For a different output location:

```sh
SLSKDBAR_OUTPUT_APP="/path/to/slskdbar.app" bash scripts/build-app.sh
```

Create a compressed release DMG:

```sh
bash scripts/build-dmg.sh
```

The result is `dist/slskdbar-2.0.0.dmg`. To use an installed Developer ID
Application certificate for both the app and DMG:

```sh
SLSKDBAR_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bash scripts/build-dmg.sh
```

## Configure

Open **Settings** from the menu bar:

- **General** changes the slskd URL, notifications, launch at login, and the
  optional transfer-count display.
- **Locations & Apps** changes the runtime config, downloads, config, logs, data,
  and SoulseekQt paths.
- **Appearance** previews and replaces the icon used for each connection state.

Default locations are derived from the current macOS account. The default
downloads folder is `~/Downloads/Soulseek`; it can be replaced with an external
volume or any other folder in Settings.

## Development

```sh
swift test
swift build
bash scripts/manual-qa.sh
```

The project intentionally has no third-party runtime dependencies. `SlskdMenuCore`
contains configuration parsing, REST models, transfer aggregation, and the
SignalR protocol client. `SlskdMenuApp` contains the AppKit menu bar and settings
interface.

See [Architecture](docs/ARCHITECTURE.md), [Contributing](CONTRIBUTING.md), and
[Security](SECURITY.md) for more detail.

## Related projects

- [slskd](https://github.com/slskd/slskd)
- [Nicotine+ downloads](https://nicotine-plus.org/doc/DOWNLOADS.html)
- [SoulseekQt downloads](https://www.slsknet.org/news/node/1)

## License

slskdbar is available under the [MIT License](LICENSE).
