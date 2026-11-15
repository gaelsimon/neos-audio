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
- Xcode 16.0 or later for the Mac app, Xcode 26 or later for the iPhone and iPad app
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

# The iPhone and iPad app, built from the same sources
xcodebuild -project Neos.xcodeproj -scheme NeosMobile -destination 'generic/platform=iOS Simulator' build
```

### Running tests

```bash
# Mac unit tests only; the Neos scheme also runs the Mac UI tests, which need an unlocked screen
# and the automation-mode authorisation
xcodebuild test -project Neos.xcodeproj -scheme Neos -destination 'platform=macOS' -only-testing:NeosTests

# Mac app + UI tests
xcodebuild test -project Neos.xcodeproj -scheme Neos -destination 'platform=macOS'

# The shared unit tests on iOS
xcodebuild test -project Neos.xcodeproj -scheme NeosMobile -destination 'platform=iOS Simulator,name=<an iPhone simulator>'

# The iPhone and iPad UI tests, in demo mode; a simulator needs no authorisation
xcodebuild test -project Neos.xcodeproj -scheme NeosMobileUITests -destination 'platform=iOS Simulator,name=<an iPhone or iPad simulator>'

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

### Uploading to the Mac App Store

```bash
DEVELOPMENT_TEAM=XXXXXXXXXX \
APP_SIGN_IDENTITY="Apple Distribution: ..." INSTALLER_SIGN_IDENTITY="3rd Party Mac Developer Installer: ..." \
PROVISIONING_PROFILE=path/to/profile.provisionprofile \
APPSTORE_APP_ID=... APPSTORE_KEY_PATH=... APPSTORE_KEY_ID=... APPSTORE_ISSUER_ID=... \
./scripts/appstore.sh 1.6.0
```

The App Store build compiles with `APP_STORE`, which swaps the Ko-fi link in About for one to the
support page and leaves out the daily check of GitHub releases that tells DMG users about a newer
version, and gets a timestamp build number unless one is passed as the second argument. The
archive is signed ad hoc, then the script embeds the Mac App Store profile, signs the app and the
installer package with identities from the keychain, and uploads with `altool`. Xcode's
cloud-managed signing is not used: when the certificate name has an accented letter, its export
writes a designated requirement the signature does not satisfy, and App Store Connect rejects the
build (ITMS-90238). `DESTINATION=export` keeps the package local instead of uploading it.

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
- Code only the Mac app needs goes in a `macOS` folder, which the iPhone and iPad target leaves out; code only the iPhone and iPad app needs goes in an `iOS` folder, which the Mac target leaves out. A component that differs per platform keeps both versions in one file, behind `#if os(macOS)`.
- Pages pad their sides with `pageMargins()`, or `listMargins()` for rows that pad their own content, so everything lines up with the page title. On iPhone and iPad that title lives in the navigation bar, never in the page.
- On iPhone and iPad the app's tint is white, so bars, buttons and links stay neutral. Anything that marks a state, such as the playing track, a selection or a switch, sets `DS.Colors.accent` itself.
- Where the platforms differ, decide in one place. A capability of the platform, such as hover or swipe to remove, is a `DS` constant (`DS.revealsControlsOnHover`, `DS.removesRowsBySwiping`). A layout decision follows the size class through an environment value in `PageLayout.swift`. The device itself comes from `DeviceIdiom`. A rule about the app's state, such as when to name the speaker, belongs on `AppState` with a test, not in a view. A rule of the iPhone and iPad shell, such as which tab shows or what opening a place does to a stack of pages, is a type of its own in `Utilities/iOS`, with its tests in `NeosTests/iOS`.
- A button drawn as a bare glyph takes `hitTarget()`. A frame alone leaves the tap to the glyph, so a finger aiming at the square around it misses.
- Prefer the platform's own controls: `Form` for settings, labelled `Toggle`, `Picker` and `TextField`, `.keyboardShortcut` for Return and Escape in sheets. A custom control needs a reason the native one cannot meet, written next to it.
- Text takes its font and colour from `typography()`. A colour other than the role's goes through `typography(_:color:)`: a `foregroundStyle` chained after it never shows for most roles, and SwiftLint rejects it.
- A form shown as a sheet goes through `FormSheet`, and a page shown as a sheet through `DoneSheet`. Both cap the text size, which a sheet on iPhone and iPad does not inherit from the page behind it; a sheet built another way calls `cappedTextSize()` itself. A field for an address, an e-mail or a URL takes `literalTextInput`.
- Settings and caches are read and written through `AppDefaults.store`. Demo mode swaps it for a store of its own, emptied at each launch, so a demo or a UI test run neither shows nor changes what the app saved for a real speaker; SwiftLint rejects `UserDefaults.standard`.
- Tests for new behaviour. The app and the protocol package each have their suite, keep that bar.

## Pull request process

1. Fork and create a feature branch from `main`.
2. Make your changes. Keep commits focused.
3. Run `swiftlint` and the test suite locally; both must pass.
4. Open a PR with a clear description: what changed, why, and what speaker(s) you tested against.
5. CI will run lint, the Mac and iPhone tests, and the SonarCloud quality gate, which reads the coverage of both.

## Questions

Open a GitHub issue. There's no Discord, no mailing list.
