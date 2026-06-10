# UPnP ContentDirectory Research

> **Date**: April 2025
> **Device**: Marantz MODEL 40n (firmware 3.88.532, Aios 6.0V)
> **Goal**: Determine if UPnP ContentDirectory can replace/supplement HEOS CLI browse to get track duration for browse items.

## TL;DR

**ContentDirectory only exposes physical audio inputs; not streaming services.** Track duration for Tidal/SoundCloud/etc. browse items is not available through any protocol the device exposes. The HEOS app likely uses Denon's private cloud API or direct streaming service APIs.

## Device UPnP Architecture

The device description at `http://<IP>:60006/upnp/desc/aios_device/aios_device.xml` exposes **4 sub-devices**:

| Sub-device | Type | Services |
|-----------|------|----------|
| **MediaRenderer** | `urn:schemas-upnp-org:device:MediaRenderer:1` | AVTransport, ConnectionManager, RenderingControl, QPlay |
| **AiosServices** | `urn:schemas-denon-com:device:AiosServices:1` | ErrorHandler, ZoneControl:2, GroupControl |
| **ACT-Denon** | `urn:schemas-denon-com:device:ACT-Denon:1` | ACT (volume limit, device control) |
| **MediaServer** | `urn:schemas-upnp-org:device:MediaServer:1` | **ContentDirectory**, ConnectionManager |

### Services Used by Neos

| Service | Control URL | Status |
|---------|------------|--------|
| AVTransport | `/upnp/control/renderer_dvc/AVTransport` | ✅ Used (seek, position, metadata) |
| ACT | `/ACT/control` | ✅ Used (volume limit) |
| ContentDirectory | `/upnp/control/ams_dvc/ContentDirectory` | ❌ Investigated, not useful |

### Services NOT Used (potential future)

| Service | Control URL | Potential Use |
|---------|------------|---------------|
| RenderingControl | `/upnp/control/renderer_dvc/RenderingControl` | Volume, mute via UPnP |
| ZoneControl:2 | `/upnp/control/AiosServicesDvc/ZoneControl` | Zone/room management |
| GroupControl | `/upnp/control/AiosServicesDvc/GroupControl` | Speaker grouping |
| QPlay | `/upnp/control/renderer_dvc/QPlay` | Tencent QPlay (China) |

## ContentDirectory Browse Results

### Root (ObjectID=0)

```
TotalMatches: 1
```

Single container: `inputs/` (childCount=7, class: `object.container.local.inputs`)

The device description confirms this is by design:
> *"Shares User defined folders and files to other Universal Plug and Play media devices."*

### Inputs Container (ObjectID=inputs/)

7 physical audio inputs:

| Item ID | Title |
|---------|-------|
| `inputs/coax_in_1` | Coaxial In |
| `inputs/optical_in_1` | Optical In |
| `inputs/line_in_1` | Line In |
| `inputs/hdmi_arc_1` | HDMI OUT (ARC) |
| `inputs/cd` | CD |
| `inputs/phono` | Phono |
| `inputs/recorder_in_1` | Recorder |

Each input item includes:
- `<upnp:class>object.item.audioItem.audioBroadcast.input</upnp:class>`
- `<res>` with stream URL (e.g., `http://<IP>:8015/analoginput/analog/analog/0/coaxin1`)
- Denon-specific `<desc>` elements: `inputLevel`, `hidden`, `inUse`

### Other ObjectIDs Tested

All return **Error 500 (Internal Error)**:
- Numeric IDs: `1`, `2`, `5`, `1028`
- Named IDs: `tidal`, `music`, `sources`, `services`, `online`, `streaming`

**Conclusion**: Streaming services are not exposed through ContentDirectory.

## How Duration IS Available

### Currently Playing Track

Two sources provide duration for the active track:

1. **HEOS CLI event** `player_now_playing_progress`:
   ```
   pid=123&cur_pos=60000&duration=240000
   ```
   Duration in milliseconds. Already used by `EventRouter` → `AppState.setProgress()`.

2. **UPnP AVTransport** `GetPositionInfo`:
   ```xml
   <TrackDuration>0:04:32</TrackDuration>
   ```
   Already used by `HEOSService.fetchPlaybackPosition()`.

3. **DIDL-Lite metadata** from `GetCurrentState` / `GetPositionInfo`:
   ```xml
   <res duration="00:00:36" sampleFrequency="48000" bitsPerSample="24">...</res>
   ```
   `DIDLLiteParser` extracts sampleFrequency, bitsPerSample, etc. but **ignores** the `duration` attribute. Could be extracted but is redundant with sources above.

### Browse Items (NOT Available)

The HEOS CLI `browse/browse` response returns:
```json
{
  "name": "Track Name",
  "type": "song",
  "mid": "m123",
  "artist": "Artist",
  "album": "Album",
  "image_url": "https://...",
  "playable": "yes"
}
```

**No duration field.** No protocol available to the device provides this for browse items.

## How the HEOS App Likely Gets Duration

The official HEOS app shows duration for Tidal/SoundCloud tracks in browse lists. Possible mechanisms:

1. **Denon Cloud API**: The HEOS app authenticates with Denon's servers (account sign-in), which may proxy streaming service metadata including duration.

2. **Direct Streaming Service APIs**: The app may have embedded Tidal/SoundCloud API keys and fetches track metadata directly from the service.

3. **Private HEOS Protocol Extension**: There may be undocumented HEOS CLI commands or an entirely separate API (HTTPS to Denon cloud) not in the public protocol spec.

None of these are accessible to third-party apps without reverse-engineering the HEOS app's network traffic.

## DIDL-Lite Parser Gap (Minor)

The `DIDLLiteParser.swift` extracts `<res>` attributes but skips `duration`:

```swift
// Currently extracted:
let sampleRate = resNode?.attribute(forName: "sampleFrequency")
let bitDepth = resNode?.attribute(forName: "bitsPerSample")
let channels = resNode?.attribute(forName: "nrAudioChannels")
let bitrate = resNode?.attribute(forName: "bitrate")

// Available but NOT extracted:
// resNode?.attribute(forName: "duration")  → "0:04:46" format
```

This is a trivial fix but provides no new value since duration is already available from `player_now_playing_progress` events for the playing track.

## Recommendations

1. **No action needed** on ContentDirectory; it cannot provide what we need.
2. **Duration in browse lists** is not achievable with available protocols.
3. **Future option**: If Denon opens their cloud API, or if someone reverse-engineers the HEOS app's Tidal integration, this could be revisited.
4. **ContentDirectory inputs data** could potentially replace the HEOS CLI input source browsing (`browse/browse?sid=<input_sid>`), but offers no meaningful advantage.
