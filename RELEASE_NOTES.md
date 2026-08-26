# Ryotunes v2.3 — Ryoku polish release

v2.3 folds the first post-v2.2 field fixes into one testable release line. It keeps the audio-only native playback, WebKit hibernation, MPRIS, tray lifecycle and stable Home architecture from v2.2 while fixing the startup geometry and polishing the two most visible UI rough edges reported after release.

## Fixed in v2.3

### Ryoku / Hyprland startup geometry
- The managed Ryoku window rule now owns the full startup policy: float, **1760×1000**, and center.
- This fixes the small-window launch seen when Tauri's post-map resize request lost to compositor policy.
- The title match remains exact, so the separate `Ryotunes Mini` window is not affected.

### Home playback console spacing
- Added balanced vertical breathing room around Previous / Play-Pause / Next / Queue controls.
- The controls no longer visually touch the divider beneath them.
- The existing card dimensions are retained by tightening nearby metadata spacing rather than simply enlarging the hero.

### Light theme
- Reworked Light mode from a mostly beige/white plane into a restrained multi-family palette.
- Main content remains warm parchment.
- Sidebar/navigation gains muted sage.
- Titlebar/playerbar gains blue-grey separation.
- Primary playback actions use a muted clay/terracotta accent.
- Toolbars and section furniture use restrained gold/sage/blue/clay detail.
- Queue/detail surfaces get a cooler paper tint so the lanes are easier to distinguish.
- The additional colour is static: no animated gradients or new compositor-heavy effects were added.

## Preserved release behavior
- Audio-only playback through native libmpv.
- Event-driven playback state with no permanent high-frequency frontend clock.
- Linux main-WebKit hibernation during background playback.
- MPRIS, hardware media keys and Ryoku shell controls during background playback.
- Five-minute tray-only idle exit when nothing is playing.
- Explicit Quit teardown for playback, MPRIS and integrations.
- Stable Home DOM; physical Home virtualization remains disabled.
- Mini-player, lyrics, queue and release-performance safeguards from v2.2.

## Packaging

The v2.3 replacement package identity is **`ryotunes-v2.3 2.3.0-1`**.

It keeps `ryoku-desktop` installed, preserves the genuine stock Ryotunes entry points for rollback, installs the custom binary under `/usr/lib/ryotunes-v2.3/ryotunes`, exposes one normal `/usr/bin/ryotunes` route and desktop launcher, and installs the managed Ryoku window rule.
