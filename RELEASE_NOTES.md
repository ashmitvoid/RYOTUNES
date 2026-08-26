# Ryotunes v2.2 — final Ryoku-shell release candidate

v2.2 is built for end users rather than a tester workflow. It consolidates the v2.1 field fixes and the final visual/interaction feedback into one cleaned release candidate while preserving the native playback/background architecture that made v1.6+ efficient on Ryoku.

## Final field fixes

### Main window and interface density
- Increased the hidden pre-map fallback to 1760×1000 logical pixels and the adaptive mapped target to roughly 92% × 84% of the active monitor work area. This avoids the old 1440×840 fallback that could become the visible default on Wayland before monitor mapping completed.
- The main surface remains floating, centered, non-maximized by default, while manual maximize remains available during the session.
- Changed the default UI scale from 120% to 110%. Fresh/untouched installs use 110%; explicitly persisted custom scales remain respected; Ctrl+0 resets to 110%.

### Mini-player
- Increased the widget canvas slightly and rebalanced artwork/content proportions.
- Replaced compressed text tabs with an icon-led Now Playing / Lyrics / Queue switcher with larger hit areas and deliberate spacing.
- Compact lyrics no longer inherit remembered full-panel manual scroll positions. Active-line centering uses viewport geometry, compact manual-scroll suppression is shorter, and top/bottom reading-zone padding keeps the current lyric visible instead of clipping it at the top.
- Kept the mini-player action-menu suppression and the v2.1 R3 full-app restore lifecycle fix.

### Visual polish
- Reworked Light/Follow-System-Light into a lower-glare warm-stone palette with clearer hierarchy between canvas, sidebar, cards, panels and player surfaces.
- Removed the rectangular seek focus box that WebKit showed after pointer forward/rewind. Keyboard focus uses the seek rail itself rather than an outer rectangle.
- Increased breathing room between transport controls and seek/divider lines in the bottom player and Home listening console.
- Settings/header divider lines now stop before the close-button zone so the close control reads as a clean isolated action.
- Warm pre-theme base tokens prevent a bright pure-white flash while the semantic theme is being applied.

## Preserved release gates

- Audio-only frontend/backend contract.
- Linux user-facing WebKit hibernation while native playback continues.
- Five-minute tray-only idle exit and explicit Quit/MPRIS/native playback teardown.
- Stable Home DOM with session cache and no mount/unmount virtualization.
- Bounded Search continuation, deduplication, state preservation and contained nested scrolling.
- Shared right-click / two-finger / Shift+F10 / Menu-key context actions.
- Bounded decode-before-swap large-artwork cache.
- Reduced Motion and Low Resource guards.
- Cold-start and reconstructed-window ready handshake with native recovery deadlines.

## Packaging

The public package is **`ryotunes-v2.2 2.2.0-1`**. The managed installer migrates v2.1/v2.0/v1.9 and older custom generations, preserves the true stock Ryoku rollback copy, never removes `ryoku-desktop`, installs the real binary at `/usr/lib/ryotunes-v2.2/ryotunes`, exposes one normal `/usr/bin/ryotunes` and desktop launcher, installs the user-scoped Ryoku floating rule and fails closed if ownership/routes do not validate.
