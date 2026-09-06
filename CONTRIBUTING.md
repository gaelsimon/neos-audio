# Contributing to Neos

Thanks for your interest in contributing. Neos is a small, focused project and contributions are very welcome, from bug reports to PRs to test reports against speakers I can't test myself.

## Ways to help

- **Test against your speaker.** Neos has been primarily tested against Marantz MODEL 40n. Reports from other Denon/Marantz HEOS-enabled models (especially older ones, AVRs, and grouped speaker setups) are highly valuable.
- **Test untested music services.** Spotify, Amazon Music, Pandora, Napster, and others should work via the HEOS protocol but haven't been verified.
- **File issues** for bugs, crashes, or missing features.
- **Submit PRs** for fixes or improvements.

## Development setup

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)

### Building

```bash
# Regenerate the Xcode project from project.yml
xcodegen generate

# Open in Xcode
open Neos.xcodeproj

# Or build from the command line
xcodebuild -project Neos.xcodeproj -scheme Neos -configuration Release build
```

### Running tests

```bash
# App + UI tests
xcodebuild test -project Neos.xcodeproj -scheme Neos -destination 'platform=macOS'

# The HEOS protocol layer has its own tests, in its own repository
git clone https://github.com/gaelsimon/swift-heos && cd swift-heos && swift test
```

### Building a release DMG locally

```bash
./scripts/release.sh 1.6.0
```

With no credentials in the environment this produces an ad-hoc signed DMG in `build/`, which shows
the Gatekeeper warning on first launch. Set `CODE_SIGN_IDENTITY`, `DEVELOPMENT_TEAM` and the
`NOTARY_*` variables to get a signed, notarised one.

### Signing and notarisation in CI

The Release workflow signs and notarises when the repository holds Developer ID credentials, and
falls back to an ad-hoc DMG when it does not, so a fork still builds. Enabling it needs an Apple
Developer Program membership and these repository secrets:

| Secret | What it is |
|---|---|
| `MACOS_CERTIFICATE` | Developer ID Application certificate, exported as `.p12`, base64 encoded |
| `MACOS_CERTIFICATE_PWD` | Password set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any string; unlocks the throwaway keychain the runner creates |
| `APPLE_TEAM_ID` | Ten-character team identifier |
| `NOTARY_KEY` | App Store Connect API key, the `.p8` file, base64 encoded |
| `NOTARY_KEY_ID` | Key ID shown next to the key in App Store Connect |
| `NOTARY_ISSUER_ID` | Issuer ID shown above the key list |

Encode the two files with `base64 -i cert.p12 | pbcopy`. An App Store Connect API key is used rather
than an Apple ID password because it survives a password change and needs no second factor.

Notarisation is an automated malware scan, not App Review: there are no guidelines to satisfy and
nothing to submit for approval. It usually takes two to fifteen minutes, which is why the release job
allows more time than the build needs.

## Architecture

```
Neos (SwiftUI App)
├── MenuBarExtra with .window style
├── @Observable AppState (single source of truth)
├── MVVM ViewModels calling AudioService
│
NeosDomain (from the swift-heos package)
└── Vendor-neutral domain models and AudioService protocol
│
HEOSKit (from the swift-heos package)
├── Models: Player, NowPlayingMedia, TrackMetadata, etc.
├── Protocol: HEOSCommand, CommandBuilder, ResponseParser, DIDLLiteParser
├── Networking: TCPTransport, HEOSConnection, AVRControlClient, UPnP clients
├── Discovery: SSDPDiscovery, SSDPNotifyListener, DeviceDiscovery
└── Services: PlayerService, GroupService, BrowseService, SystemService
```

The UI layer depends only on `NeosDomain`. `HEOSKit` is the only module that knows about the HEOS protocol. Both come from [swift-heos](https://github.com/gaelsimon/swift-heos), so protocol changes belong there and app changes belong here. Swapping in a different speaker backend would mean another package conforming to `AudioService`.

### Key design rules

- **Zero third-party runtime dependencies.** Apple frameworks only (Network.framework, Foundation, Security).
- **Actor-based concurrency** for thread safety.
- **`HEOSCommand` enum** with associated values for type-safe commands.
- **AsyncStream** for event handling, not Combine.
- **MVVM with service layer pattern.**

## Network protocols

Neos speaks five protocols to the same device. See [HEOS_CLI_ProtocolSpecification](https://rn.dmglobal.com/usmodel/HEOS_CLI_ProtocolSpecification-Version-1.17.pdf) (Denon's public spec) for the primary one.

| Protocol | Port | Purpose |
|----------|------|---------|
| HEOS CLI | TCP 1255 | Commands, events, browsing |
| UPnP AVTransport | HTTP 60006 | Seek, position, track metadata (DIDL-Lite) |
| UPnP ACT Denon | HTTP 60006 | Hardware volume limit |
| AVR Telnet | TCP 23 | Power on/off |
| SSDP | UDP 1900 | Device discovery |

Sample HEOS CLI responses live in `docs/samples/` and are useful test fixtures.

## Code style

- SwiftLint enforces the project style; `swiftlint` must pass before a PR can land.
- Match existing patterns. Small focused files, MVVM, no force unwraps (`!`) outside test code.
- Tests for new behaviour. The app has over 400 unit tests and the protocol package has its own, keep that bar.

## Pull request process

1. Fork and create a feature branch from `main`.
2. Make your changes. Keep commits focused.
3. Run `swiftlint` and the test suite locally; both must pass.
4. Open a PR with a clear description: what changed, why, and what speaker(s) you tested against.
5. CI will run lint, tests, and the SonarCloud quality gate.

## Questions

Open a GitHub issue. There's no Discord, no mailing list.
