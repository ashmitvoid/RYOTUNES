<div align="center">
  <img src="src-tauri/icons/128x128.png" width="96" alt="Ryotunes icon" />

# Ryotunes

**Music, shaped for the Ryoku desktop.**

A Linux-first desktop music player built around native audio playback, a quiet background footprint, and a UI designed to belong on Ryoku rather than sit on top of it.

`Ryoku / CachyOS / Arch` · `Tauri 2` · `Rust` · `Svelte 5` · `libmpv`

</div>

---

Ryotunes is deliberately audio-only. The Rust backend owns playback through libmpv while the Svelte interface handles discovery, library work, lyrics, queue management and the rest of the desktop experience. Closing the main window during playback can hibernate the expensive user-facing WebKit renderer without stopping the song, MPRIS controls, tray controls or Ryoku's media surface.

That split is the centre of the project: the player should feel rich when it is on screen and get out of the way when it is not.

## What it does

**Listening**
- Search and browse songs, albums, artists and playlists.
- Queue management, radio/continuation and gapless native playback.
- Synced lyrics with compact mini-player follow mode.
- Local music alongside online playback.
- Like, library and playlist actions.

**Desktop**
- MPRIS and hardware media-key integration.
- System tray with background playback and explicit Quit semantics.
- Ryoku/Hyprland-aware floating window behaviour.
- Compact Now Playing / Lyrics / Queue mini-player.
- Discord Rich Presence, Last.fm and optional Listen Together support.
- Dark, light and system themes, reduced-motion and low-resource modes.

**Performance**
- Native mpv playback rather than audio in the UI renderer.
- Event-driven playback state instead of a permanent high-frequency frontend clock.
- Main WebKit hibernation while playing in the background.
- Stable Home DOM with bounded progressive loading rather than physical section virtualization.
- Session caches and bounded artwork decode/cache paths.
- Tray-only idle exit when nothing is playing.

## Install

Ryotunes v2.2 targets **x86_64 Ryoku, CachyOS and Arch-based systems**.

The normal user release is **precompiled**. Installing Ryotunes does not require Node, pnpm, Rust, Cargo or a local Tauri build.

Download `ryotunes-v2.2-2.2.0-1-x86_64.pkg.tar.zst` from the [v2.2.0 release](https://github.com/ashmitvoid/RYOTUNES/releases/tag/v2.2.0), then install it with:

```bash
sudo pacman -U ./ryotunes-v2.2-2.2.0-1-x86_64.pkg.tar.zst
```

A binary AUR recipe is maintained in [`aur/`](aur/) and is intended to make the user path simply:

```bash
paru -S ryotunes-bin
```

For source builds and development setup, see [`docs/INSTALL-ARCH.md`](docs/INSTALL-ARCH.md).

## A Ryoku-first application

Ryotunes does not treat Ryoku as a skin. The Linux build has explicit integration for the shell and compositor:

- stable application identity: `dev.ryoku.ryotunes`
- Ryoku-style floating/centred main-window policy
- MPRIS state that remains available after the main UI is closed
- shell media controls that keep working during WebKit hibernation
- close-to-tray separated from explicit Quit
- rollback-safe packaging that does not remove `ryoku-desktop`

The details are documented in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repository map

```text
crates/
  innertube/          YouTube Music request/model layer
  player/             native playback core
  listen-protocol/    shared Listen Together protocol
  sync-server/        optional room relay
src-tauri/             desktop host, lifecycle, MPRIS, tray and integrations
ui/                    SvelteKit interface
packaging/             Linux / Arch / Ryoku packaging
scripts/               diagnostics and release gates
docs/                  install, architecture, troubleshooting and release notes
```

## Development

The project uses locked frontend and Rust dependency graphs. A release is expected to pass both the repository preflight and native compiler gates.

```bash
cd ui
pnpm install --frozen-lockfile
pnpm check
pnpm build

cd ..
cargo fmt --all -- --check
cargo test --workspace --locked
cargo check --workspace --locked
cargo tauri build --no-bundle
```

The release checklist is in [`docs/RELEASE-CHECKLIST.md`](docs/RELEASE-CHECKLIST.md).

## Troubleshooting

Start with [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md). For a bug report, include the distro, Ryoku/Hyprland version, display server, GPU setup, and the output of the bundled diagnostics script where relevant.

## Upstream and license

Ryotunes is a GPL-3.0-or-later modified work derived from [SimoHypers/LiMusic](https://github.com/SimoHypers/limusic). Ryotunes has its own Ryoku-focused product direction, interface and lifecycle/performance work while retaining and adapting parts of the original Rust/Tauri/YouTube Music stack.

The detailed upstream note is in [`UPSTREAM.md`](UPSTREAM.md). The project is distributed under the terms in [`LICENSE`](LICENSE).

Ryotunes is an independent project and is not affiliated with or endorsed by YouTube or Google. YouTube and YouTube Music are trademarks of Google LLC.
