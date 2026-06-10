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

# HEOSKit (Swift Package, no Xcode required)
cd HEOSKit && swift test

# NeosDomain (Swift Package, no Xcode required)
cd NeosDomain && swift test
```

### Building a release DMG locally

```bash
./scripts/release.sh 1.6.0
```

This produces an **unsigned** DMG in `build/`. CI does the same for tagged releases. Signing/notarization would require an Apple Developer Program subscription ($99/year); happy to wire it up later if someone wants to fund it.

## Architecture

```
Neos (SwiftUI App)
├── MenuBarExtra with .window style
├── @Observable AppState (single source of truth)
├── MVVM ViewModels calling AudioService
│
NeosDomain (Local Swift Package)
└── Vendor-neutral domain models and AudioService protocol
│
HEOSKit (Local Swift Package)
├── Models: Player, NowPlayingMedia, TrackMetadata, etc.
├── Protocol: HEOSCommand, CommandBuilder, ResponseParser, DIDLLiteParser
├── Networking: TCPTransport, HEOSConnection, AVRControlClient, UPnP clients
├── Discovery: SSDPDiscovery, SSDPNotifyListener, DeviceDiscovery
└── Services: PlayerService, GroupService, BrowseService, SystemService
```

The UI layer depends only on `NeosDomain`. `HEOSKit` is the only module that knows about the HEOS protocol. Swapping in a different speaker backend would mean adding a sibling package that conforms to `AudioService`.

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
- Tests for new HEOSKit functionality. HEOSKit has ~200 unit tests, keep that bar.

## Pull request process

1. Fork and create a feature branch from `main`.
2. Make your changes. Keep commits focused.
3. Run `swiftlint` and the test suite locally; both must pass.
4. Open a PR with a clear description: what changed, why, and what speaker(s) you tested against.
5. CI will run lint, tests, and the SonarCloud quality gate.

## Questions

Open a GitHub issue. There's no Discord, no mailing list.
