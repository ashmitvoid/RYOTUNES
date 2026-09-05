# Ryotunes architecture

Ryotunes is split so that playback survives independently of the visible interface. This is especially important on Ryoku laptops, where keeping a WebKit view active for a song that is already playing wastes CPU, memory and power.

## Process model

The Tauri/Rust process is authoritative for playback and desktop integration. The SvelteKit WebView is a client of that state rather than the clock that drives it.

```text
Ryoku / Hyprland
       │
       ├── MPRIS + media keys + tray
       │             │
       ▼             ▼
  Tauri / Rust ── player crate ── libmpv
       │
       ├── Innertube / library / integrations
       │
       └── visible WebKit UI (SvelteKit)
                    │
                    ├── Home / Search / Library
                    ├── Queue / Lyrics / Now Playing
                    └── Mini player
```

## Crates and binaries

The workspace separates the playback core from whoever renders it. Phase 1 of the native-client plan moved everything in `src-tauri/src` that is not a window, a webview or a Tauri command into `crates/core`, behind three host traits; the daemon, CLI and QML rows below are the targets later phases add.

| Path | Role | Origin |
|---|---|---|
| `crates/innertube`, `crates/player`, `crates/listen-protocol`, `crates/sync-server` | unchanged | existing |
| `crates/core` | `AppState`, orchestrator, db, lyrics, local, discord, lastfm, media (MPRIS), radio, listentogether, cipher, potoken, session (login), settings. No Tauri. Talks to the outside through three traits (4.2) | moved from `src-tauri/src` |
| `crates/protocol` | request/response/event types, `serde` only, shared by daemon, CLI, tests | new |
| `crates/ryotunesd` | binary: socket server, single-instance lock, systemd-friendly lifecycle, GTK thread hosting the hidden WebKitGTK views, tray | new; absorbs `tray.rs`, `webview.rs`, the login part of `session.rs` |
| `crates/ryotunes-cli` | `ryotunes-cli <method> [json]` and `ryotunes-cli events`; the shell's and scripts' entry point | new |
| `client/` | the QML client run by Quickshell: `qs -c ryotunes` (shipped as `/usr/share/ryotunes/client`), plus `client/mini/` for the mini player window | new, replaces `ui/` |
| `src-tauri/` | deleted at the end of phase 4 | removed |

## Daemon

`ryotunesd` hosts `crates/core` behind a unix socket so the interface can be killed without stopping playback. It is a systemd user service, socket-activated by `ryotunesd.socket` on the first client connection, and it exits on a bounded idle (nothing playing and no subscriber) after five minutes.

- Socket: `$XDG_RUNTIME_DIR/ryotunes/ryotunesd.sock`, in a `0700` directory, created under `umask 077`. A single instance is enforced with an `flock` on `ryotunesd.sock.lock`; a second launch connects to the incumbent, asks it to `show`, and exits 0.
- Framing: newline-delimited JSON, one object per line, both directions. Request `{"id":12,"method":"play","params":{"videoId":"…"}}`; response `{"id":12,"result":…}` or `{"id":12,"error":{"code":"…","message":"…"}}`; event `{"event":"position","data":{"position":12.3}}`.
- Methods: every `#[tauri::command]` name and JSON shape, plus the control methods `hello` (returns `{"protocol":1,"daemon":"2.4.1"}`), `subscribe` (opts into events and replies with the current `playback`/`queue`/`settings`/`auth` snapshot), `show` (raise a subscribed client's window, or launch the client when none is listening), `quit` (stop playback, unregister MPRIS, exit), and `sign_in` (open the Google login window).
- `ryotunes-cli <method> [json]` runs one method and prints its `result`; `ryotunes-cli events [name…]` subscribes and prints one event per line until interrupted.

The Tauri app and the daemon share the same data directory (`$XDG_DATA_HOME/dev.ryoku.ryotunes`); run one at a time until the cutover.

## Background playback

Closing the main window is not the same operation as quitting the application.

When playback is active, Ryotunes can destroy/hibernate the expensive user-facing WebView while keeping the native backend alive. MPRIS, tray actions and Ryoku shell media controls therefore continue without retaining the full renderer. Reopening reconstructs the WebView and resynchronises it from native state.

A tray-only session with no playback has a bounded idle lifetime and exits automatically. Explicit Quit stops the playback session, unregisters MPRIS and shuts integrations down immediately.

## UI update model

Playback state is event-driven. Ryotunes avoids a permanent high-frequency frontend transport clock and avoids heavy requestAnimationFrame/FFT loops for ordinary idle playback.

Home uses a stable DOM. Sections are not physically mounted/unmounted as the user scrolls; progressive loading, containment and session caching are preferred because physical virtualization previously caused visible jumps and extra renderer work.

Search loads results incrementally in bounded pages, deduplicates them and preserves query, selection and scroll state when navigating back.

## Artwork

Large artwork paths reuse already available thumbnails, prepare higher-resolution images before swapping them into view, reject stale track requests, and keep the cache bounded. The goal is to avoid blank artwork and decode spikes during queue/Now Playing changes.

## Linux / Ryoku lifecycle

The main window uses the stable application id `dev.ryoku.ryotunes`. On Ryoku, a compositor rule floats and centres the main surface before it becomes visible. Native geometry remains a fallback rather than the primary source of a tiled-to-floating transition.

Cold launch, second-instance launch, tray reopen and mini-player-to-main restoration all converge on the same native visibility lifecycle. The UI sends a mounted/ready signal, with a native failsafe so a hidden WebView cannot deadlock the application in a tray-only state.

## Packaging invariants

The Ryoku replacement package is intentionally conservative:

- never uninstall the `ryoku-desktop` package;
- preserve genuine stock entry points for rollback;
- expose one active `/usr/bin/ryotunes` route and one desktop launcher;
- migrate old custom Ryotunes generations only after the new generation is active;
- install/remove only the Ryotunes-managed Hyprland rule;
- verify binary ownership and active routes after installation.

## Release gates

`scripts/release-check.sh` runs source-level structural and regression checks. A distributable build must additionally pass Svelte/TypeScript semantic checking, locked Cargo fetch/test/check, the native Tauri release build and final pacman package ownership validation on an Arch/Ryoku build machine.
