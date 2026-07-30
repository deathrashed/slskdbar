# Architecture

slskdbar is a small AppKit application split into two Swift Package Manager
targets.

## SlskdMenuCore

The core target contains code that does not depend on AppKit:

- Runtime configuration and API-key parsing
- Preferences and application-discovery models
- slskd REST requests and response models
- SignalR framing and WebSocket connection management
- Transfer aggregation

## SlskdMenuApp

The app target owns:

- The status item and menus
- Connection-state icons
- Settings and native file pickers
- Login-item integration
- macOS notifications
- Application discovery through Launch Services

## Activity model

The application hub at `/hub/application` pushes server state changes. Slskd
slskdbar keeps that lightweight connection open and does not poll for status.

Transfer details are requested only when the menu opens. The optional counts
beside the menu bar icon use `/hub/metrics`; that second event connection exists
only while the setting is enabled.

Connect, disconnect, transfer cleanup, and the manual refresh action use the
slskd REST API. The runtime API key is loaded from the configured `slskd.yml`
file at the request boundary.

## Distribution

`scripts/build-app.sh` tests the package, creates a release build, assembles the
`.app` bundle, copies resources, and applies an ad-hoc signature by default.
`scripts/build-dmg.sh` packages it with an Applications shortcut. Set
`SLSKDBAR_CODESIGN_IDENTITY` to a Developer ID Application identity to enable
the hardened runtime and distribution signing. Public binary releases should
also be notarized and stapled.
