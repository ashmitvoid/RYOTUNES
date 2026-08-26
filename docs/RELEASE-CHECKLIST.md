# Ryotunes v2.2 release checklist

## Build/package gates
1. Verify frozen source checksum and extract into a disposable clean tree.
2. Install exact frontend dependencies with the frozen lockfile and run `pnpm check`.
3. Run `cargo fmt --all -- --check`, workspace tests, locked/offline Linux graph verification, native Tauri release build and sync-server release build.
4. Use an isolated final `CARGO_TARGET_DIR`; never package a pre-existing release binary.
5. `makepkg` produces `ryotunes-v2.2-2.2.0-1-x86_64.pkg.tar.zst`; package content/ownership checks pass.
6. `/usr/bin/ryotunes` resolves to `/usr/lib/ryotunes-v2.2/ryotunes`; exactly one normal Ryotunes desktop launcher is visible.
7. `ryoku-desktop` remains installed. Removing `ryotunes-v2.2` restores the backed-up real stock Ryoku entry points.

## Window/startup
8. A genuine cold start shows the main UI on the **first invocation** (never tray-only until a second launch) and maps directly as a centered floating Ryotunes window at about 89% × 84% of usable work area, without a tiled/fullscreen flash.
9. Desktop launcher, terminal, autostart and tray reconstruction produce the same floating default; manual maximize is not persisted as the next cold-start default.
10. Cold start and tray reconstruction reveal only after the frontend is mounted; no black/blank startup frame.
11. Mini-player renders polished Playing/Lyrics/Queue views; its WM close does not reopen full Ryotunes, its action menus are absent only inside mini, and Open Full Ryotunes keeps mini visible until the main UI is actually shown.

## Home/Edit Home
12. Above-fold Home becomes usable before optional lower enrichment; revisit from another page is near-instant from session cache.
13. Scroll Home continuously: visible loaded shelves never refetch/reorder/remount due to viewport movement; lower sections append quietly with stable dimensions.
14. No Music Videos/video-only Home entry appears.
15. Mixed artist-seeded recommendation shelves never render `// <artist>`; display heading is `// You might also like`.
16. Edit Home lists the same supported registry as Home, identifies unavailable/hidden state, shows drag insertion position, Save applies, Cancel reverts and Reset returns to canonical order.

## Search/actions
17. Full Search is vertically scrollable beyond the first batch, owns nested touchpad/wheel scrolling without moving the page behind it, and loads bounded continuation pages near the bottom without duplicates or scroll jumps.
18. Search query, selection and list scroll survive page navigation/back; Up/Down continues through loaded batches; the Home/global dropdown and category result pages also continue past their first bounded responses.
19. Selected-result inspector is populated appropriately for song/artist/album/playlist.
20. `⋯` is visible at idle everywhere track/item actions are offered, in Dark and Light.
21. Right-click/two-finger context click and Shift+F10/Menu open the same track menu at a fitted location and never play the track.
22. Verify Play next, Add to queue, Start radio, Like/Save, Dislike, Go to artist, Shortcuts, Share and Add to playlist where applicable.

## Player/queue/lyrics/UI
23. Queue reorder is smooth, vertically constrained, has a visible insertion rule, edge auto-scroll and no accidental playback/text selection.
24. Queue search/scroll state survives Queue ↔ Lyrics switches; lyrics scroll and per-track timing offset persist.
25. Mini Lyrics auto-follows the active line without opening the full app and remains lightweight during playback.
26. Large Queue/Now Playing/mini artwork shows an immediate cached/thumbnail placeholder and swaps decoded final artwork without black boxes or layout shift; rapid track changes do not show stale art.
27. Settings/Open Music Link/Listen Together and other standard dialogs share the outer-edge close control and consistent Escape/focus behavior.
28. Dark, professional Light and Follow System switch without resetting playback/navigation; Reduced Motion and Low Resource Mode reduce decorative work.

## Integrations/lifecycle
29. MPRIS and Ryoku QS controls play/pause/seek/next correctly before and after main-WebKit hibernation/reopen.
30. Discord disabled mode performs no repeated IPC work; unavailable Discord backs off; enabled activity updates and shuts down on Quit.
31. Start on login matches actual OS registration and launches the current normal `/usr/bin/ryotunes` route.
32. Close-to-tray + active playback keeps native playback/MPRIS alive with no user-facing main WebKit renderer.
33. Tray only + no active playback starts the five-minute exit deadline; playback or UI restore cancels/resets it.
34. Five full minutes without playback/UI fully exits and removes MPRIS/Music Island state.
35. Explicit Quit tears down playback, media state/MPRIS and integrations immediately; it never waits for the five-minute timer.

## Resource/stability acceptance
36. `resource-check.sh` discovers Ryotunes through `/proc/<pid>/exe`, not argv matching, and captures cold/visible-idle/active-scroll samples.
37. Run visible idle with and without playback, Home active touchpad scrolling, Low Resource OFF vs ON and background playback. Background should contain no main user-facing WebKit process.
38. `background-check.sh`, `pause-resume-check.sh`, `quit-check.sh` and `tray-idle-exit-check.sh` pass.
39. Run `long-session-check.sh` for 30–60 minutes while exercising Home/Search/Artist/Album/Playlist/Library/Queue/Lyrics/Settings/mini-player. After settling, CPU and PSS should stop climbing and return near the established idle band.
40. Record actual v2.2 field numbers; do not infer them from static/source validation.
