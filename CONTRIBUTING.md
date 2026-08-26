# Contributing to Ryotunes

## Setup

Install the Linux/Tauri prerequisites described in `README.md`, then install frontend dependencies:

```bash
cd ui
pnpm install
pnpm check
cd ..
```

For development with hot reload:

```bash
cargo tauri dev
```

## Validation

Before submitting a change, run:

```bash
cargo fmt --all --check
cargo test --all
cd ui && pnpm check && pnpm build
```

Network-dependent provider tests may be ignored by the default Rust test run; execute relevant ignored tests when changing extraction or lyrics providers.

## UI conventions

- Preserve the Ryotunes product hierarchy: **Ryotunes** / `RYOTUNES` / `RYOKU // MUSIC`.
- Use the existing Ryoku paper/ink tokens and live palette bridge; do not introduce an independent theme system.
- Artwork may retain colour. Functional chrome stays paper-and-ink.
- Use one-pixel hairlines and the established 6px geometry.
- Motion is state feedback: snap, move and swap timings come from Ryoku's live motion settings.
- Do not add custom wheel physics. The Home touchpad routing exists only to keep vertical gestures working over horizontal WebKitGTK shelves.
- Prefer existing HugeIcons and UI primitives over introducing another icon/component library.
- Keep YouTube/network logic behind the Rust command boundary.
- New ornament belongs only in real dead space and must not overlap controls or music content.

## Scope

Ryotunes talks to services that can change independently of the application. Extraction, lyrics and rich integrations should therefore fail softly and keep local playback/UI usable when a provider is unavailable.
