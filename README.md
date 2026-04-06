# neos-audio

Curated collection of high-quality internet radio stations for [Neos](https://github.com/gasim/neos), a macOS controller for Denon/Marantz HEOS speakers.

## Why?

Most internet radio directories (TuneIn, etc.) serve low-bitrate MP3 streams. HEOS speakers support lossless and high-bitrate codecs — FLAC, AAC 320kbps, WAV, ALAC — so they deserve better sources.

This repository maintains a hand-picked catalog of stations that stream in high quality.

## Structure

```
stations/
  catalog.json        # Station catalog (array of station objects)
images/
  {station-id}.png    # Station logos (512x512 recommended)
```

## Station Schema

Each station in `catalog.json`:

| Field       | Type     | Required | Description                              |
|-------------|----------|----------|------------------------------------------|
| `id`        | string   | yes      | Unique identifier (kebab-case)           |
| `name`      | string   | yes      | Display name                             |
| `streamURL` | string   | yes      | Direct stream URL (HTTP/HTTPS)           |
| `codec`     | string   | yes      | `flac`, `aac`, `mp3`, `wav`, `alac`      |
| `bitrate`   | int      | no       | Bitrate in kbps (omit for lossless)      |
| `sampleRate`| int      | no       | Sample rate in kHz (e.g. 44, 48, 96)     |
| `genre`     | string   | yes      | Primary genre                            |
| `country`   | string   | yes      | ISO 3166-1 alpha-2 country code          |
| `language`  | string   | no       | ISO 639-1 language code                  |
| `website`   | string   | no       | Station website URL                      |
| `imageURL`  | string   | auto     | Resolved from GitHub raw URL + `images/` |

## Image URLs

Station images are hosted in the `images/` directory. The Neos app resolves image URLs using:

```
https://raw.githubusercontent.com/gasim/neos-audio/main/images/{station-id}.png
```

Recommended format: 512x512 PNG with transparent background.

## Codec Support (HEOS)

| Codec | Bitrate            | Sample Rate     |
|-------|--------------------|-----------------|
| FLAC  | Lossless           | 44.1–192 kHz    |
| AAC   | 48–320 kbps        | Up to 48 kHz    |
| MP3   | 32–320 kbps        | Up to 48 kHz    |
| WAV   | Lossless           | 44.1–192 kHz    |
| ALAC  | Lossless           | 44.1–192 kHz    |

## Contributing

Contributions welcome! To add a station:

1. Verify the stream URL works and serves the advertised codec/bitrate
2. Add the station object to `stations/catalog.json`
3. Add a 512x512 PNG logo to `images/{station-id}.png`
4. Open a pull request

## License

This catalog is provided as-is for personal use with Neos.
