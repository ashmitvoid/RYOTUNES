# Ryotunes v2.4 — Radio, device playlists and Discord presence controls

v2.4 expands Ryotunes beyond an account-only YouTube Music workflow without changing the native
playback/lifecycle architecture that keeps it quiet on Ryoku. The release adds demand-driven
Internet Radio, persistent playlists that work while signed out, and a configurable Discord
"Listening to …" title.

## Internet Radio

- A dedicated **Radio** surface is now available from Discover in the Ryoku sidebar.
- Station metadata comes from the community-run Radio Browser directory.
- Opening Radio fetches a bounded first page of popular stations; searching and **Load more** are
  explicit user actions. There is no startup Radio request and no permanent Radio polling loop.
- Directory requests use mirror discovery plus a short fallback set, bounded timeouts and broken
  station filtering.
- Selecting a station hands its validated HTTP(S) stream directly to the existing native libmpv
  playback path. The frontend never owns the stream clock.
- Station click registration is best-effort and never blocks or fails playback.
- A small bounded native station cache allows a persisted live-radio queue to be restored without
  treating a synthetic station id as a YouTube video id.
- Live Radio stays out of YouTube-only actions: ratings, YouTube radio seeds, YouTube playlist
  writes and YouTube share links are not offered for a station.
- Live Radio does not enter On Repeat, Last.fm scrobbles, lyrics lookup or Home artist
  personalization.
- Listen Together deliberately rejects Live Radio in v2.4 because another peer cannot resolve a
  station record cached only on this machine.

## Device playlists — no Google account required

- **New playlist** is now available while signed out in both Library and the expanded sidebar.
- Signed-out playlists are persistent **device playlists** stored in Ryotunes' SQLite database.
  Their songs, ordering metadata and names survive app restarts and Google sign-in/sign-out.
- Device playlists remain visible and usable after signing in; signing out never clears them.
- The Add to playlist dialog no longer dead-ends when no playlist exists:
  - **+ New playlist** is available inside the picker.
  - **Create + add** creates the playlist and immediately adds the pending song(s).
- Device playlists support add, remove, rename, delete and local custom artwork.
- Their artwork stays local; it is never uploaded automatically.
- Device playlist ids are namespaced away from YouTube browse ids and are never used as YouTube
  autoplay/radio seeds.
- The existing fast saved-in-playlists membership index now includes device playlists even while
  signed out.

When signed in, the normal **New playlist** action still creates a YouTube Music playlist. v2.4
does not silently convert or upload an existing device playlist.

## Custom Discord "Listening to …" title

- Settings → General now includes **Discord presence title**.
- The default remains **Music**.
- A custom 2–128 character value changes the activity label Discord renders as
  **Listening to <your text>**.
- Changing only this title invalidates the Rich Presence dedup state and refreshes the active card
  without restarting playback.
- Ryotunes' Discord application/client identity remains fixed; this setting changes vanity text,
  not which application owns the presence.
- Existing connection backoff, disabled-mode parking, send throttling and Quit teardown remain in
  place.

## Performance and lifecycle preserved

- Audio playback remains native through libmpv.
- Main WebKit hibernation during background playback remains intact.
- MPRIS, hardware media keys, Ryoku shell controls and tray playback remain native.
- No permanent high-frequency frontend timer was added for Radio, playlists or Discord title
  updates.
- Five-minute tray-only idle exit remains unchanged when nothing is playing.
- Explicit Quit still tears down playback, MPRIS and integrations immediately.
- Home retains its stable non-virtualized section architecture and bounded artwork pipeline.
- Live Ryoku theme updates remain event-driven rather than polled.

## Packaging

The v2.4 replacement package identity is **`ryotunes-v2.4 2.4.0-1`**.

It keeps `ryoku-desktop` installed, preserves the genuine stock Ryotunes entry points for rollback,
installs the custom binary under `/usr/lib/ryotunes-v2.4/ryotunes`, exposes one normal
`/usr/bin/ryotunes` route and desktop launcher, and installs the managed Ryoku window rule.

The v2.4 installer recognizes v2.3 as a previous custom package rather than stock, removes the old
custom package after installing v2.4, then reasserts the v2.4 replacement route so the previous
uninstall hook cannot leave the stock launcher active.
