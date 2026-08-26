# Changelog


### FINAL R3 visibility hotfix
- Fixed a Linux hidden-window deadlock where the main WebView started with `visible:false` but its reveal handshake was queued behind `requestAnimationFrame`; WebKitGTK can suspend rAF for hidden toplevels, leaving Ryotunes running only in the tray even after repeated launches.
- The mounted Svelte tree now sends readiness immediately, with bounded timer retries.
- Added a native reveal deadline for cold start, reconstructed main windows, and second-launch recovery so a lost frontend readiness message cannot leave the application permanently invisible.
- Added release invariants guarding against reintroducing rAF-gated hidden-window readiness and requiring the native recovery path.

## v2.2 — 2026-08-27

- Promoted Ryotunes to the final Ryoku-shell user release candidate.
- Raised default floating main-window fallback to 1760×1000 logical and adaptive mapped geometry to ~92% × 84% of monitor work area.
- Changed untouched/fresh UI scale default and Ctrl+0 reset from 120% to 110%, while retaining persisted custom values.
- Redesigned mini-player spacing and icon-led Now/Lyrics/Queue navigation; fixed compact active-lyric clipping and stale manual-scroll restoration.
- Lowered Light/Follow-System-Light luminance and strengthened surface hierarchy.
- Removed pointer seek focus rectangles while keeping keyboard seek focus legible.
- Added breathing room around bottom-player and Home listening-console transport controls.
- Stopped Settings/header divider lines before the close-control zone.
- Kept v2.1 R3 cold-start/reopen native reveal failsafes, Search pagination, Home stable-DOM behavior, background WebKit hibernation and native Quit/MPRIS teardown.

## v2.1 — 2026-08-27

- Fixed first-launch visibility with one native frontend-ready handshake shared by cold start and reconstructed WebViews.
- Fixed mini-player expand-to-main race by retaining the mini surface until the full UI is actually visible.
- Replaced transient Hyprland map-rule injection as the primary policy with a Ryoku-style persistent `hl.window_rule`; adaptive work-area geometry stays native and hidden before reveal.
- Added real bounded Search continuation through Innertube/Tauri/UI for mixed, song, album, artist and playlist result streams; removed practical first-page ceilings.
- Isolated Search nested scrolling so touchpad/wheel gestures cannot chain into the background page.
- Redesigned the mini-player visual shell and segmented PLAYING/LYRICS/QUEUE navigation; removed action menus only from mini queue rows.
- Added mini-safe keyboard transport handling and kept one central full-app shortcut registry.
- Reworked Light mode to a warm layered stone palette rather than bright white surfaces.
- Preserved audio-only playback, background WebKit hibernation, five-minute tray idle shutdown, explicit Quit teardown, stable Home DOM and bounded artwork/cache paths.


## v2.0 — 2026-08-26

- Canonicalized the frozen v2.0 Cargo.lock from the target-machine Cargo diff: removed stale `httpdate` and `tauri-plugin-window-state` lock entries and the stale `hyper -> httpdate` edge. The builder now requires `cargo fetch --locked` to accept the shipped lockfile directly and never performs an unlocked refresh.
- Fixed native `pnpm check` blockers found during the first target-machine build: keyed-each `animate:flip` structure in Edit Home, module/instance `BrowseItem` import collision in Search, listbox option focus semantics, and deprecated Svelte module-script syntax.
- Added complete compact Now Playing/Lyrics/Queue mini-player views using shared queue/lyrics state.
- Added bounded decode-before-swap artwork preparation shared by large Now Playing and mini-player artwork.
- Replaced the full-Search eight-result snapshot with a bounded scrollable/incremental result workspace and richer selected-result detail panel.
- Centralized track context actions across visible ⋯, pointer context click and keyboard context invocation; ⋯ actions are now visible at idle.
- Introduced one Home/Edit Home section registry, central video-shelf rejection and central seed-artist heading normalization to `You might also like`.
- Made session-cached Home stable on revisit instead of silently revalidating visible page-one shelves while scrolling.
- Added stable Tauri GTK/Wayland app id plus pre-map Hyprland float/89%×84%/center rules and retained native geometry fallback.
- Unified cold-start and Linux tray-reopen hidden-until-frontend-ready reveal behavior to avoid blank WebKit frames.
- Reworked Light mode into layered page/card/panel/sidebar/player tokens and standardized shared dialog close geometry.
- Preserved audio-only playback, event-driven transport, background WebKit hibernation, five-minute tray idle exit, Low Resource Mode and deterministic explicit Quit.
- Rebuilt release invariants, `/proc/<pid>/exe` diagnostics and zero-touch `ryotunes-v2.0 2.0.0-1` replacement packaging.

## v1.9 — 2026-08-26

- Adaptive centered Ryoku/Hyprland floating window (~89% × 84% of monitor work area) with no stale maximized/fullscreen restore.
- Restored and redesigned the 640×200 Ryoku-style mini-player; its boot surface can no longer cover the compact UI.
- Faster perceived cold start/reopen by showing the themed shell first and deferring optional visitor, local-library, Listen Together, cipher and search-prewarm work.
- Search suggestion/full-search consistency: reliable All Results handoff, recent-search structure and standard track actions.
- Familiar Artists top-track actions, clear `More like <artist>` headings and audio-only filtering of video shelves/results.
- Darker muted Light theme, safer live Ryoku accents, long-title clipping and seek/focus styling fixes.
- Queue drag commit/settle refinement, Queue/Lyrics state retention, shelf navigation and large-playlist filtering.
- Discord `Listening to Music` branding/backoff/logging cleanup and authoritative Linux autostart synchronization.
- Preserved five-minute tray-only no-playback exit, deterministic explicit Quit and Low Resource/background-WebKit architecture.
- Robust process diagnostics and zero-touch Ryoku replacement packaging with newest-available stock-backup migration.

## v1.7 R4 — 2026-08-26

- Hardened explicit Quit into one authoritative shutdown path: stop mpv, clear/drop MPRIS, close Discord presence, leave Listen Together with a bounded timeout, then exit.
- Kept paused background playback resumable from Ryoku QS/MPRIS; Pause no longer means an idle/empty session.
- Closing the mini player now closes only the mini surface instead of rebuilding the full application.
- Added Follow system / Light / Dark appearance modes with a warm, low-glare light palette and Ryoku accent integration.
- Made Discord Rich Presence report Disabled / Connecting / Connected / Unavailable and react immediately to its toggle.
- Expanded Low Resource mode into native transport cadence and Home/network policy while preserving playback quality.
- Coalesced queue reorder pointer work to animation frames, kept the dragged row normal-sized and refined insertion/edge-scroll feedback.
- Improved Listen Together form readability, modal close geometry and transport-button focus treatment.
- Deferred optional cipher/network prewarm off the cold-start critical path and shortened UI reconstruction safety delays.
- Removed eager Home continuation crawling/community enrichment, bounded Familiar Artists loading and retained v1.6 WebKit hibernation/stable Home containment.

## v1.7 R2/R3 stabilization — 2026-08-26

- Fixed background pause lifecycle: paused loaded tracks remain resumable through tray/QS/MPRIS instead of triggering process exit.
- Removed eager Home continuation crawling and community search enrichment that could cause intermittent visible-idle CPU spikes.
- Made Familiar Artists demand-proximate with bounded two-at-a-time loading and reduced hero decode size.
- Slowed fallback Ryoku palette polling while retaining immediate focus/visibility refresh.
- Added managed Ryoku replacement packaging so the public launcher is singular while `ryoku-desktop` itself remains installed and recoverable.

## v1.6 — 2026-08-26

- Added Linux main-WebKit hibernation during background playback and automatic idle process shutdown when no UI/audio remains.
- Restored stable R4 Home layout; removed the v1.5 mount/unmount virtualization that caused scrolling bounce and renderer churn.
- Reduced background transport cadence and removed healthy-path transport-watchdog wakeups.
- Tightened browse/artwork/speculative-work budgets without destroying and recreating Home sections.
- Refined pointer queue reordering with insertion gaps, edge auto-scroll and click suppression.
- Fixed Lyrics footer/source/timing controls clipping at short and floating window heights.
- Preserved R4 account-menu, artist-artwork, playback-progress, scrollbar and low-cost visualizer fixes.

## v1.4 — 2026-08-25

- Maintenance release 2: removed the permanent frontend transport clock, made PoToken helpers demand-driven, tightened helper teardown, reduced artwork-accent work and simplified touchpad fallback ownership.
- Fixed account popover overlap at titlebar scaling and Familiar Artists hero artwork flicker.
- Fixed lyric auto-follow scrollbar flashing and horizontal overflow.
- Added smooth playback-position rendering with stale-event recovery from mpv.
- Removed the Home back-to-top overlay.
- Restored a lightweight playback-state visualizer without a JavaScript analyser loop.
- Renamed the public release line to v1.4 and cleaned release/package metadata.

## V23 — 2026-08-25

- Unified playlist metadata grid, deterministic/failure-safe playlist heroes and smart-playlist identities.
- Unified ranked local search and refined Add Shortcut/Queue/list search surfaces.
- Settings Keybinds reference driven from the live shortcut registry.
- App-wide non-document selection behaviour with editable fields preserved.
- Memory pass: smaller bounded caches, smaller decoded artwork requests and open-only heavy overlays.
- Preserves V22 audio-only/native playback, low-resource mode, touchpad and responsive-layout behaviour.

## V22 — 2026-08-25

- Added Low resource mode, queue search and Stop after current.
- Added Recently Played / Rediscover smart playlists and on-demand Listening Insights.
- Added per-track lyric timing correction plus low-cost next-track lyric prefetch.
- Added portable playlist JSON import/export and optional Quickshell/MPRIS widget.
- Preserved V21 responsive/touchpad/audio-only fixes and tightened resource invariants.

## V21 Final — 2026-08-25

- Fixed Home search suggestion clipping/stacking, shallow-window layout and visible mood-chip scrollbar.
- Restored native two-finger touchpad ownership; the WebKit fallback now intervenes only if native pixel scrolling does not move.
- Replaced the ambiguous interlocking Open Link glyph with one authored external-link mark.
- Rebuilt the seek rail as a static SVG waveform + straight remainder while preserving native click/drag/keyboard seeking.
- Reduced playback render wakeups: word-synced lyrics are bounded to 30 Hz, active-line lookup is binary, deep Home shelves use content visibility and the last regular-playback backdrop blur is gone.
- Backported authoritative Like-state refresh and private-upload stream validation fix.
- Added artwork accent caching/prewarming and targeted blurred-artwork compositor promotion.
- Added consistent contextual menus to Home tiles.
- Kept the application strictly audio-only.


## 20.0.0 — 2026-08-24

V20 is the release-candidate cleanup pass. It keeps the recovered V18/V19 Now Playing geometry frozen, adds global peel-by-peel Escape navigation toward Home, synchronizes Lyrics Focus with the global transient-state stack, and removes obsolete version-scoped release wiring. The seven V19 craft fixes remain intact.

## 19.0.0 — 2026-08-24

V19 is a focused craft/stability release: the recovered Now Playing geometry is frozen while seven interaction and rendering defects are corrected.

- Preserve square audio artwork without stretching.
- Remove the dead Lyrics/Lyrics Focus right-hand lane.
- Play Quick Results songs directly on row click.
- Replace the malformed Open Link toolbar glyph with stable chain geometry.
- Escape returns Search/Library to Home after transient surfaces close.
- Remove filled hover background from dialog close buttons.

## 18.0.0 — 2026-08-24

V18 is the restoration release: it keeps the V17 reliability work, but replaces the unstable V17 Now Playing geometry with an isolated layout derived from the proven V14/Ryowalls composition.

### Now Playing restoration

- Rebuilt Now Playing with isolated V18 classes so legacy V17 layout overrides cannot fight its geometry.
- Restored the V14/Ryowalls-style 5/12 media + 7/12 Queue/Lyrics split on wide desktops.
- Bounded audio artwork to a calm square media plate and gave music video its own contained 16:9 surface.
- Preserved the current playback/video-sync logic while removing the layout paths that produced giant artwork, dead gutters, page leakage and unstable queue widths.
- Queue and Lyrics share one stable detail lane; Lyrics Focus is a dedicated single-lane focus mode.
- Collapsed and expanded sidebar states keep the same Now Playing composition.
- At narrow desktop widths the media preview yields to the detail lane instead of overflowing the viewport.

### Ryoku interface hardening

- Left-aligned Settings with the rest of sidebar navigation.
- Kept the native Hugeicons Open Link glyph rather than the malformed custom chain mark.
- Preserved the corrected bone-on-ink Play/Pause hover/active treatment.
- Preserved aspect-aware Ryoku editorial art for Search, Library, Data & Storage and About.
- Preserved the redundant-sidebar-search removal, refined Search workspace and authenticated Library artwork path.
- Preserved V15-style atmospheric line motion with reduced-motion support.

### Reliability retained from V17

- centralized queue/lyrics ownership;
- route scroll restoration;
- duplicate playback-request protection and resolving state;
- Home first-paint deferral for non-critical enrichment;
- WebKitGTK video paint-containment fix;
- unified overlay stage and route recovery UI;
- current-line recovery for manually scrolled lyrics.

### Release gate

Run `scripts/release-check.sh`, then `pnpm check`, `pnpm build`, `cargo check --workspace`, `cargo test --workspace`, and `cargo tauri build --no-bundle` on the target Ryoku/Arch machine. Finish with a real visual regression pass covering Home, Search, Library, Settings, Now Playing audio/video, Queue, Lyrics and sidebar collapse/expand.

## Build hotfix

- Restored the typed `showMenu` and `contextMenu` TrackRow props used by compact QueueList/mini-player menu suppression. This fixes the v2.1 FINAL `svelte-check` failure reported during the native build gate.
