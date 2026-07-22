# Neos — Context Glossary

A glossary of the domain language used in Neos. Definitions only — no implementation details.

## Source

What a user calls a "source" is a **music service** in the domain model (`MusicSource`). It is any top-level place music comes from: a streaming service (Tidal, SoundCloud, TuneIn, Deezer) or a local-music server reachable over the network. A source may be **searchable** (it advertises search criteria) or browse-only.

> Note: in the UI and casual speech this is called a "source"; in code it is a `MusicSource` and the search filter that selects one is `selectedServiceFilter`. Treat "source" and "service" as the same concept at this level.

## Sub-source

A music server discovered *inside* another source. For example, individual DLNA/UPnP media servers found by browsing into the "Local Music" source. Sub-sources are discovered lazily (by browsing the parent) and can carry their own search criteria, so they appear as first-class searchable sources alongside top-level ones.

## Search criteria

The set of categories a source declares as searchable (e.g. Tracks, Artists, Albums, Playlists), each identified by a `scid`. A source with no search criteria is not searchable; if it is a local-music server, Neos browses into it to find sub-sources that are.

## Now Playing track vs. Browse item

A **browse item** is a row in a browse or search list (song, album, artist, playlist, station, container). Browse items carry name, artist, album, and artwork — but **no duration**: the HEOS protocol does not expose per-track duration for list items.

The **now-playing track** is the single track currently loaded on the speaker. Only this track has a duration, available via playback-progress events and UPnP `TrackDuration`. (See `docs/UPNP_CONTENT_DIRECTORY_RESEARCH.md`.)
