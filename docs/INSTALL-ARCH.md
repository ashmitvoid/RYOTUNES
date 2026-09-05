# Install on Arch / CachyOS / Ryoku

Ryotunes is primarily distributed as a precompiled x86_64 pacman package. Normal users should install that package rather than compiling the Tauri application locally.

## Precompiled package

After downloading the package from the matching GitHub release:

```bash
sudo pacman -U ./ryotunes-v2.4-2.4.0-1-x86_64.pkg.tar.zst
```

The Ryoku distribution bundle also carries the managed migration/rollback helper used when replacing the stock Ryoku entry point. Use that bundle on systems where Ryotunes is already provided by `ryoku-desktop`.

## AUR binary package

The intended AUR package is `ryotunes-bin`. It downloads the precompiled release payload rather than compiling Rust/Tauri locally.

```bash
paru -S ryotunes-bin
```

This command will become usable after the AUR package is published.

## Native QML client (preview)

Alongside the Tauri application, the package ships a native [Quickshell](https://quickshell.org) client that talks to the same `ryotunesd` daemon. It installs to `/usr/share/ryotunes/client` and is launched by the `ryotunes-qml` wrapper (a `Ryotunes (QML)` desktop entry is also installed). Because Quickshell resolves `qs -c NAME` only from `$XDG_CONFIG_HOME/quickshell/NAME`, the wrapper runs the packaged tree by explicit path:

```bash
ryotunes-qml            # == qs -p /usr/share/ryotunes/client
```

It needs the optional `quickshell` dependency and the Ryoku QML runtime (`Ryoku.Ui.Singletons`).

The two clients share one rule: **only one player at a time**. `ryotunesd` and the Tauri app each carry their own audio engine, so `/usr/bin/ryotunes` first checks for a running daemon (its instance lock, never the socket, which systemd keeps open while the daemon is idle-exited). With a daemon live it asks it to `show` (raise the connected client, or open `ryotunes-qml`) and exits; with none it is the standalone Tauri app as before. The daemon's tray "Show" and second-launch path always open `ryotunes-qml`. So the desktop's launcher, keybind and dock keep running plain `ryotunes` and get whichever client owns playback.

## Build from source

Developers can build the repository directly. On Arch-based systems you need the normal Rust/Tauri frontend toolchain plus the runtime dependencies listed in `packaging/arch/PKGBUILD`.

```bash
cd ui
pnpm install --frozen-lockfile
pnpm check
pnpm build

cd ..
cargo fmt --all -- --check
cargo test --workspace --locked
cargo tauri build --no-bundle
```

For a pacman package from the local checkout:

```bash
cd packaging/arch
makepkg -si
```

Before publishing a build, follow `docs/RELEASE-CHECKLIST.md` rather than treating a successful local compile as a release gate.
