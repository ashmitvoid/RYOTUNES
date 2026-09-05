# Core Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move everything in `src-tauri/src` that is not a window, a webview or a Tauri command into a Tauri-free `crates/core` crate behind three traits, leaving the Tauri host a thin adapter with identical behaviour.

**Architecture:** `crates/core` owns `AppState`, the orchestrator, database, lyrics, local library, integrations, cipher and PoToken. It reaches the outside world only through `EventSink` (server push), `JsBridge`/`JsSession` (a JavaScript environment), `LoginFlow` (interactive sign-in) and a `Paths` value. The Tauri host in `src-tauri` implements the three traits with `AppHandle::emit`, `webview.rs` and `session.rs`, and every `#[tauri::command]` becomes a forwarder into `core`. This is phase 1 of `docs/superpowers/specs/2026-09-05-native-client-design.md`; phases 2-4 (daemon, QML client, cutover) get their own plans once this lands.

**Tech Stack:** Rust 2021 workspace (`Cargo.toml` at the repo root), tokio, serde, `async-trait`, Tauri 2 (host only), libmpv via `crates/player`, `crates/innertube`.

**Spec:** `docs/superpowers/specs/2026-09-05-native-client-design.md`

## Global Constraints

- `cargo test --workspace --locked`, `cargo check --workspace --locked`, `cargo fmt --all -- --check` and `scripts/release-check.sh` must pass after every task (they are the release gates in `README.md`).
- No behaviour change: the Svelte UI, the hidden cipher/PoToken webviews, MPRIS, tray, Last.fm, Discord, Listen Together and login work exactly as before; `RUST_LOG=info` logs show the same `cipher: building webview`, `PoToken minter ready`, `resolved stream client="WEB_REMIX"` lines.
- `crates/core` must not depend on `tauri`, `tauri-plugin-*`, `webkit2gtk` or `ksni`; `cargo tree -p ryotunes-core -i tauri` must print `error: package ID specification tauri did not match any packages`.
- Commit subjects follow the existing history style (`build: ...`, `host: ...`, `core: ...`), imperative, no trailing period, no attribution trailers.
- Do not touch `ui/`, `crates/innertube`, `crates/player`, `crates/listen-protocol`, `crates/sync-server`.
- The workspace `Cargo.lock` is locked: adding `async-trait` is the only new dependency; add it to `[workspace.dependencies]` and run `cargo update -p async-trait --precise <version>` once, commit the lock.

---

### Task 1: Scaffold `crates/core` with the host traits

**Files:**
- Create: `crates/core/Cargo.toml`
- Create: `crates/core/src/lib.rs`
- Create: `crates/core/src/host.rs`
- Modify: `Cargo.toml` (workspace members + `async-trait`)
- Test: `crates/core/src/host.rs` (`#[cfg(test)]`)

**Interfaces:**
- Produces: `ryotunes_core::host::{EventSink, JsBridge, JsSession, JsError, LoginFlow, LoginResult, LoginError, Paths}` used by every later task.

- [ ] **Step 1: Add the crate to the workspace**

`Cargo.toml` (root):

```toml
[workspace]
resolver = "2"
members = [
    "crates/innertube",
    "crates/player",
    "crates/listen-protocol",
    "crates/sync-server",
    "crates/core",
    "src-tauri",
]

[workspace.dependencies]
# ... existing lines unchanged ...
async-trait = "0.1"
ryotunes-core = { path = "crates/core" }
```

- [ ] **Step 2: Write `crates/core/Cargo.toml`**

```toml
[package]
name = "ryotunes-core"
version.workspace = true
edition.workspace = true
license.workspace = true
description = "Ryotunes playback core: state, orchestration, integrations. No UI."

[dependencies]
serde = { workspace = true }
serde_json = { workspace = true }
tokio = { workspace = true, features = ["net", "io-util"] }
tracing = { workspace = true }
anyhow = { workspace = true }
thiserror = { workspace = true }
async-trait = { workspace = true }
futures-util = { workspace = true }
rand = { workspace = true }
listen-protocol = { workspace = true }
innertube = { path = "../innertube" }
player = { path = "../player" }
rusqlite = { version = "0.32", features = ["bundled"] }
base64 = "0.22"
regex = "1"
urlencoding = "2"
reqwest = { version = "0.12", default-features = false, features = ["rustls-tls", "gzip", "brotli", "stream"] }
souvlaki = { version = "0.8.3", default-features = false, features = ["use_zbus"] }
tokio-tungstenite = { version = "0.24", features = ["rustls-tls-webpki-roots"] }
rustls = { version = "0.23", default-features = false, features = ["ring"] }
discord-rich-presence = "1.1.0"
md-5 = "0.10"
lofty = "0.22.2"

[target.'cfg(target_os = "linux")'.dependencies]
libc = "0.2"
```

- [ ] **Step 3: Write the traits and the failing test**

`crates/core/src/lib.rs`:

```rust
//! Ryotunes playback core. Everything that is not a window lives here; the host (Tauri today, the
//! daemon tomorrow) supplies the three traits in [`host`].
pub mod host;
```

`crates/core/src/host.rs`:

```rust
//! The seams between the core and whoever hosts it.

use std::path::PathBuf;
use std::time::Duration;

use serde_json::Value;

/// Server-push channel: the host fans an event out to every listening UI.
pub trait EventSink: Send + Sync + 'static {
    fn emit(&self, event: &'static str, payload: Value);
}

#[derive(Debug, thiserror::Error)]
pub enum JsError {
    #[error("js session '{0}' does not exist")]
    Gone(String),
    #[error("js eval failed: {0}")]
    Eval(String),
    #[error("timed out after {0:?}")]
    Timeout(Duration),
    #[error("js environment reported an error: {0}")]
    BadEnvironment(String),
    #[error("js environment build failed: {0}")]
    Build(String),
}

/// A JavaScript environment able to run YouTube's player.js and BotGuard harnesses.
#[async_trait::async_trait]
pub trait JsBridge: Send + Sync + 'static {
    async fn create(
        &self,
        label: &str,
        harness_html: &str,
        init_script: &str,
    ) -> Result<Box<dyn JsSession>, JsError>;
}

/// One live environment. Mirrors `src-tauri/src/webview.rs` `Bridge` one to one.
#[async_trait::async_trait]
pub trait JsSession: Send + Sync {
    fn eval(&self, js: &str) -> Result<(), JsError>;
    async fn eval_json(&self, js: String, timeout: Duration) -> Result<Value, JsError>;
    async fn call_async(&self, expr: &str, timeout: Duration) -> Result<Value, JsError>;
    fn exists(&self) -> bool;
    fn destroy(&self);
    /// A second handle to the same environment (the PoToken minter keeps one per session).
    fn clone_session(&self) -> Box<dyn JsSession>;
}

#[derive(Debug, Clone)]
pub struct LoginResult {
    /// `name=value` pairs for the `.youtube.com` domain, as the cookie jar hands them out.
    pub cookies: Vec<(String, String)>,
    /// Google account index the user picked (`authuser`).
    pub authuser: u32,
}

#[derive(Debug, thiserror::Error)]
pub enum LoginError {
    #[error("sign-in was cancelled")]
    Cancelled,
    #[error("sign-in failed: {0}")]
    Failed(String),
}

/// The interactive Google sign-in, owned by the host because it needs a visible browser.
#[async_trait::async_trait]
pub trait LoginFlow: Send + Sync + 'static {
    async fn sign_in(&self) -> Result<LoginResult, LoginError>;
}

/// Where the core keeps its files. The host resolves them (Tauri's `app_data_dir`, or XDG).
#[derive(Debug, Clone)]
pub struct Paths {
    pub data_dir: PathBuf,
    pub cache_dir: PathBuf,
}

impl Paths {
    pub fn covers_dir(&self) -> PathBuf {
        self.data_dir.join("covers")
    }
    pub fn db_path(&self) -> PathBuf {
        self.data_dir.join("ryotunes.db")
    }
}

#[cfg(test)]
pub mod test_support {
    use super::*;
    use std::sync::Mutex;

    /// An `EventSink` that records what was emitted, for unit tests of the core.
    #[derive(Default)]
    pub struct RecordingSink {
        pub events: Mutex<Vec<(&'static str, Value)>>,
    }

    impl EventSink for RecordingSink {
        fn emit(&self, event: &'static str, payload: Value) {
            self.events.lock().unwrap().push((event, payload));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::test_support::RecordingSink;
    use super::*;

    #[test]
    fn recording_sink_keeps_order() {
        let sink = RecordingSink::default();
        sink.emit("playback-state", Value::String("playing".into()));
        sink.emit("position", serde_json::json!({ "position": 1.5 }));
        let events = sink.events.lock().unwrap();
        assert_eq!(events[0].0, "playback-state");
        assert_eq!(events[1].1["position"], 1.5);
    }

    #[test]
    fn paths_derive_children() {
        let p = Paths { data_dir: "/d".into(), cache_dir: "/c".into() };
        assert_eq!(p.covers_dir(), PathBuf::from("/d/covers"));
        assert_eq!(p.db_path(), PathBuf::from("/d/ryotunes.db"));
    }
}
```

- [ ] **Step 4: Run the tests and the isolation check**

Run: `cargo test -p ryotunes-core`
Expected: 2 passed.

Run: `cargo tree -p ryotunes-core -i tauri`
Expected: `error: package ID specification `tauri` did not match any packages`.

- [ ] **Step 5: Commit**

```bash
git add Cargo.toml Cargo.lock crates/core
git commit -m "core: add the ryotunes-core crate with the host traits"
```

---

### Task 2: Move the leaf modules

**Files:**
- Move (`git mv`): `src-tauri/src/db.rs`, `src-tauri/src/http.rs` to `crates/core/src/`
- Modify: `crates/core/src/lib.rs`, `src-tauri/src/lib.rs`, `src-tauri/Cargo.toml`

**Interfaces:**
- Produces: `ryotunes_core::{db, http}` with the same `pub` items the host used via `crate::db` / `crate::http`.

Only these two are leaves. `radio.rs` imports `crate::orchestrator::PlaybackData`, `lyrics.rs` takes `&AppState`, and `lyrics.rs`/`discord.rs` call `crate::local::is_local_song`; those three ride with the modules they depend on (`local` in Task 4, `orchestrator`/`state` in Task 5). Core can never depend on the host, so a module moves only once everything it imports is already in core.

- [ ] **Step 1: Confirm the two modules import nothing from the host**

Run: `grep -n 'tauri\|AppHandle\|crate::' src-tauri/src/db.rs src-tauri/src/http.rs`
Expected: no `tauri`/`AppHandle` hits and no `crate::` path outside `crate::db`/`crate::http` themselves.

- [ ] **Step 2: Move them and declare them**

```bash
git mv src-tauri/src/db.rs crates/core/src/db.rs
git mv src-tauri/src/http.rs crates/core/src/http.rs
```

`crates/core/src/lib.rs`:

```rust
pub mod host;

pub mod db;
pub mod http;
```

In `src-tauri/src/lib.rs` delete `mod db; mod http;` and add:

```rust
use ryotunes_core::{db, http};
```

In `src-tauri/Cargo.toml` add `ryotunes-core = { workspace = true }` under `[dependencies]`. `pub(crate)` items the host uses become `pub`.

- [ ] **Step 3: Build and test**

Run: `cargo check --workspace --locked && cargo test --workspace --locked`
Expected: both green; the `db` unit tests now run from `ryotunes-core`.

- [ ] **Step 4: Commit**

```bash
git add -A crates/core src-tauri/src src-tauri/Cargo.toml
git commit -m "core: move db and http out of the host"
```

---

### Task 3: Move cipher and PoToken behind `JsBridge`

**Files:**
- Move: `src-tauri/src/cipher/` (mod.rs, config.rs, extractor.rs, fetcher.rs) and `src-tauri/src/potoken/` (mod.rs, jsutil.rs) to `crates/core/src/`
- Move: `src-tauri/cipher_configs.json` to `crates/core/cipher_configs.json` (the `include_str!` path in `config.rs` changes to `"../../cipher_configs.json"`), `src-tauri/po_token.html` to `crates/core/po_token.html`
- Modify: `src-tauri/src/webview.rs` (implement the traits), `src-tauri/src/lib.rs` (construction)
- Test: existing `cipher::tests`, `extractor::tests`, `config::tests`, `potoken::jsutil` tests move with the files

**Interfaces:**
- Consumes: `host::{JsBridge, JsSession, JsError}` from Task 1.
- Produces: `ryotunes_core::cipher::CipherDeobfuscator::new(js: Arc<dyn JsBridge>, app_data_dir: &Path, config: Arc<PlayerConfigStore>)`, `ryotunes_core::potoken::PoTokenGenerator::new(js: Arc<dyn JsBridge>, db: Arc<Db>)`; every other method signature unchanged.

- [ ] **Step 1: Write the failing compile**

Move the directories:

```bash
git mv src-tauri/src/cipher crates/core/src/cipher
git mv src-tauri/src/potoken crates/core/src/potoken
git mv src-tauri/cipher_configs.json crates/core/cipher_configs.json
git mv src-tauri/po_token.html crates/core/po_token.html
```

Add `pub mod cipher; pub mod potoken;` to `crates/core/src/lib.rs`. Run `cargo check -p ryotunes-core`.
Expected: errors on `use tauri::AppHandle` and `use crate::webview::Bridge` in `cipher/mod.rs` and `potoken/mod.rs`; that is the list of edits for Step 2.

- [ ] **Step 2: Replace `AppHandle`/`Bridge` with the traits**

In `crates/core/src/cipher/mod.rs`:

```rust
use std::sync::Arc;
use crate::host::{JsBridge, JsSession};

#[derive(Default)]
struct Inner {
    bridge: Option<Box<dyn JsSession>>,
    // ... the other fields unchanged ...
}

pub struct CipherDeobfuscator {
    js: Arc<dyn JsBridge>,
    fetcher: PlayerJsFetcher,
    config: Arc<PlayerConfigStore>,
    inner: Mutex<Inner>,
}

impl CipherDeobfuscator {
    pub fn new(js: Arc<dyn JsBridge>, app_data_dir: &Path, config: Arc<PlayerConfigStore>) -> Self {
        CipherDeobfuscator {
            fetcher: PlayerJsFetcher::new(app_data_dir),
            config,
            inner: Mutex::new(Inner::default()),
            js,
        }
    }
}
```

Mechanical substitutions in both modules, each a one-liner:

| Before | After |
|---|---|
| `Bridge::create(&self.app, LABEL, HARNESS, init).await` | `self.js.create(LABEL, HARNESS, init).await` |
| `inner.bridge.clone()?` (cipher) | `inner.bridge.as_ref().map(\|b\| b.clone_session())?` |
| `let _ = b.destroy();` | `b.destroy();` |
| `bridge.eval_json(js, CALL_TIMEOUT).await` | unchanged |
| `bridge.call_async(expr, LOAD_TIMEOUT).await.map_err(\|e\| e.to_string())` | unchanged (`JsError` implements `Display`) |
| `tauri::async_runtime::spawn(async move { ... })` | `tokio::spawn(async move { ... })` |
| `crate::webview::Error::BadWebview(msg)` matches in `potoken/mod.rs` | `JsError::BadEnvironment(msg)` |

`Inner::default()` requires `Option<Box<dyn JsSession>>: Default`, which holds.

- [ ] **Step 3: Implement the traits on the Tauri bridge**

Append to `src-tauri/src/webview.rs`:

```rust
use ryotunes_core::host::{JsBridge, JsError, JsSession};

impl From<Error> for JsError {
    fn from(e: Error) -> Self {
        match e {
            Error::Gone(l) => JsError::Gone(l),
            Error::Eval(m) => JsError::Eval(m),
            Error::Timeout(d) => JsError::Timeout(d),
            Error::BadWebview(m) => JsError::BadEnvironment(m),
            Error::Build(m) => JsError::Build(m),
        }
    }
}

/// The host's `JsBridge`: one hidden Tauri webview per label.
pub struct TauriJs {
    pub app: AppHandle,
}

#[async_trait::async_trait]
impl JsBridge for TauriJs {
    async fn create(
        &self,
        label: &str,
        harness_html: &str,
        init_script: &str,
    ) -> Result<Box<dyn JsSession>, JsError> {
        let bridge = Bridge::create(&self.app, label, harness_html, init_script).await?;
        Ok(Box::new(bridge))
    }
}

#[async_trait::async_trait]
impl JsSession for Bridge {
    fn eval(&self, js: &str) -> Result<(), JsError> {
        Bridge::eval(self, js).map_err(Into::into)
    }
    async fn eval_json(&self, js: String, timeout: Duration) -> Result<Value, JsError> {
        Bridge::eval_json(self, js, timeout).await.map_err(Into::into)
    }
    async fn call_async(&self, expr: &str, timeout: Duration) -> Result<Value, JsError> {
        Bridge::call_async(self, expr, timeout).await.map_err(Into::into)
    }
    fn exists(&self) -> bool {
        Bridge::exists(self)
    }
    fn destroy(&self) {
        let _ = Bridge::destroy(self);
    }
    fn clone_session(&self) -> Box<dyn JsSession> {
        Box::new(self.clone())
    }
}
```

Add `async-trait = { workspace = true }` to `src-tauri/Cargo.toml`.

In `src-tauri/src/lib.rs` replace the two constructions:

```rust
let js: Arc<dyn ryotunes_core::host::JsBridge> = Arc::new(webview::TauriJs { app: handle.clone() });
let cipher = Arc::new(CipherDeobfuscator::new(js.clone(), &data_dir, config));
let potoken = Arc::new(PoTokenGenerator::new(js.clone(), db.clone()));
```

- [ ] **Step 4: Build, test, and smoke the real thing**

Run: `cargo check --workspace --locked && cargo test --workspace --locked`
Expected: green; `cipher::tests::parses_signature_cipher` and friends run from core.

Run: `cd ui && pnpm build && cd .. && cargo tauri build --no-bundle` then `RUST_LOG=info ./target/release/ryotunes` and skip to a fresh track.
Expected log lines, in order: `cipher: building webview`, `cipher analysis complete sig_available=true n_available=true`, `PoToken minter ready`, `resolved stream client="WEB_REMIX"`. Two extra `WebKitWebProcess` appear in `ps`, as before.

- [ ] **Step 5: Commit**

```bash
git add -A crates/core src-tauri
git commit -m "core: move cipher and potoken behind the JsBridge seam"
```

---

### Task 4: Move the integrations behind `EventSink` and `Paths`

**Files:**
- Move: `src-tauri/src/media.rs`, `src-tauri/src/lastfm.rs`, `src-tauri/src/local.rs`, `src-tauri/src/listentogether/` to `crates/core/src/`
- Create: `src-tauri/src/host_sink.rs` (the `EventSink` over `AppHandle`)
- Create: `src-tauri/src/local_scope.rs` (the Tauri asset-protocol allow-listing that stays in the host)
- Modify: `src-tauri/src/lib.rs`, `src-tauri/src/commands.rs`, `src-tauri/src/ryoku_theme.rs`

**Interfaces:**
- Consumes: `host::{EventSink, Paths}`.
- Produces: `ryotunes_core::media::spawn(sink: Arc<dyn EventSink>, commands: MediaCommands) -> Option<MediaHandle>` where `MediaCommands` is the channel the host already drains in `media::handle_event`; `ryotunes_core::lastfm::spawn(session_key: Option<String>) -> LastfmHandle` and `lastfm::emit_state(sink: &dyn EventSink, ...)`; `ryotunes_core::listentogether::LtSession::new(sink: Arc<dyn EventSink>, url: String)`; `ryotunes_core::local::{scan, covers_dir(paths: &Paths), ...}`.

- [ ] **Step 1: Write the host sink and its test**

`src-tauri/src/host_sink.rs`:

```rust
//! `EventSink` for the Tauri host: every core event becomes a Tauri event on every window.

use ryotunes_core::host::EventSink;
use serde_json::Value;
use tauri::{AppHandle, Emitter};

pub struct TauriSink(pub AppHandle);

impl EventSink for TauriSink {
    fn emit(&self, event: &'static str, payload: Value) {
        if let Err(e) = self.0.emit(event, payload) {
            tracing::debug!(event, error = %e, "event emit failed (no window?)");
        }
    }
}
```

There is no unit test for the sink itself (it needs a running Tauri app); its contract is covered by the smoke test in Step 5. The core side is tested with `RecordingSink` in Step 3.

- [ ] **Step 2: Move the modules and replace `AppHandle`**

```bash
git mv src-tauri/src/media.rs crates/core/src/media.rs
git mv src-tauri/src/lastfm.rs crates/core/src/lastfm.rs
git mv src-tauri/src/local.rs crates/core/src/local.rs
git mv src-tauri/src/listentogether crates/core/src/listentogether
```

Add `pub mod media; pub mod lastfm; pub mod local; pub mod listentogether;` to core's `lib.rs`.

Substitutions:

| File | Before | After |
|---|---|---|
| `media.rs:81` | `pub fn spawn(app: AppHandle) -> Option<MediaHandle>` | `pub fn spawn(sink: Arc<dyn EventSink>, commands: tokio::sync::mpsc::UnboundedSender<MediaControlEvent>) -> Option<MediaHandle>` |
| `media.rs:193` | `pub(crate) fn handle_event(app: &AppHandle, event: MediaControlEvent)` | deleted from core; the host keeps a `handle_media_event(state: Arc<AppState>, event)` in `lib.rs` draining the receiver and calling the same `AppState` methods it calls today |
| `lastfm.rs:279` | `fn emit_state(app: &tauri::AppHandle, ...)` | `pub fn emit_state(sink: &dyn EventSink, ...)` with `sink.emit("lastfm-state", json!({...}))` |
| `lastfm.rs:113,314` | `tauri::async_runtime::spawn` | `tokio::spawn` |
| `listentogether/mod.rs:146,156` | `app: AppHandle` | `sink: Arc<dyn EventSink>` |
| `listentogether/mod.rs` `emit_state` | `self.app.emit("lt-state", ...)` | `self.sink.emit("lt-state", ...)` |
| `local.rs:686` | `pub fn covers_dir(app: &tauri::AppHandle) -> PathBuf` | `pub fn covers_dir(paths: &Paths) -> PathBuf { paths.covers_dir() }` (the XDG fallbacks move into the host's `Paths` construction) |
| `local.rs:646,664` | `allow_covers`, `allow_music_paths` | moved verbatim to `src-tauri/src/local_scope.rs`, they are Tauri asset-protocol scope calls |

- [ ] **Step 3: Test the core side with the recording sink**

Add to `crates/core/src/listentogether/mod.rs` tests:

```rust
#[tokio::test]
async fn emit_state_reaches_the_sink() {
    use crate::host::test_support::RecordingSink;
    let sink = std::sync::Arc::new(RecordingSink::default());
    let (session, _rx) = LtSession::new(sink.clone(), "wss://example.invalid".into());
    session.emit_state().await;
    let events = sink.events.lock().unwrap();
    assert_eq!(events.last().map(|e| e.0), Some("lt-state"));
}
```

`RecordingSink` is `#[cfg(test)]` and `pub`, so it is reachable from core's own tests.

Run: `cargo test -p ryotunes-core emit_state_reaches_the_sink`
Expected: PASS.

- [ ] **Step 4: Wire the host**

In `src-tauri/src/lib.rs` setup:

```rust
let paths = ryotunes_core::host::Paths {
    data_dir: data_dir.clone(),
    cache_dir: cache_root.clone(),
};
let sink: Arc<dyn ryotunes_core::host::EventSink> = Arc::new(host_sink::TauriSink(handle.clone()));
let (media_tx, mut media_rx) = tokio::sync::mpsc::unbounded_channel();
let media = media::spawn(sink.clone(), media_tx);
let (lt, lt_sync_rx) = listentogether::LtSession::new(sink.clone(), lt_url);
```

and after `app_state` exists:

```rust
{
    let st = app_state.clone();
    tauri::async_runtime::spawn(async move {
        while let Some(ev) = media_rx.recv().await {
            handle_media_event(st.clone(), ev).await;
        }
    });
}
```

`handle_media_event` is the body of the old `media::handle_event`, moved into `lib.rs` unchanged apart from taking `Arc<AppState>` instead of looking it up through `app.state()`.

`ryoku_theme.rs` stays in the host for now (it is Linux desktop glue that emits `ryoku-theme-changed`): change `spawn_watcher(app: tauri::AppHandle)` to `spawn_watcher(sink: Arc<dyn EventSink>)` and `app.emit(...)` to `sink.emit(...)` so it is ready to move in phase 2.

- [ ] **Step 5: Build, test, smoke**

Run: `cargo check --workspace --locked && cargo test --workspace --locked`
Expected: green.

Run: `cargo tauri build --no-bundle && RUST_LOG=info ./target/release/ryotunes`, play a track, then `playerctl -p ryotunes pause` and `playerctl -p ryotunes play`.
Expected: the UI reflects both changes within a second (the `playback-state` event went through `TauriSink`); `busctl --user list | grep MediaPlayer2.ryotunes` shows the MPRIS name; Settings shows the Last.fm status card unchanged.

- [ ] **Step 6: Commit**

```bash
git add -A crates/core src-tauri
git commit -m "core: move media, lastfm, local and listen together behind EventSink"
```

---

### Task 5: Move `orchestrator.rs`, `state.rs`, their dependants and the session logic

**Files:**
- Move: `src-tauri/src/orchestrator.rs`, `src-tauri/src/state.rs`, `src-tauri/src/radio.rs`, `src-tauri/src/lyrics.rs`, `src-tauri/src/discord.rs` to `crates/core/src/` (the last three were deferred from Task 2: `radio` imports `orchestrator::PlaybackData`, `lyrics` takes `&AppState`, `lyrics`/`discord` call `local::is_local_song`, which Task 4 put in core)
- Split: `src-tauri/src/session.rs` into `crates/core/src/session.rs` (cookie/account bookkeeping, `allowed_login_navigation` and its tests) and `src-tauri/src/login_webview.rs` (the visible Google login window, implementing `LoginFlow`)
- Modify: `src-tauri/src/lib.rs`, `src-tauri/src/commands.rs`

**Interfaces:**
- Consumes: everything above.
- Produces: `ryotunes_core::state::AppState::new(it, clients, player, db, sink: Arc<dyn EventSink>, login: Arc<dyn LoginFlow>, paths: Paths, orchestrator, lt, media, discord, lastfm)`; `AppState::sign_in(self: &Arc<Self>)` which awaits `self.login.sign_in()` and then runs today's cookie-application code; `AppState::emit(&self, event, payload)` replacing every `self.app.emit`; `ryotunes_core::{radio, lyrics, discord}` with their existing `pub` items.

- [ ] **Step 1: Move and let the compiler list the edits**

```bash
git mv src-tauri/src/orchestrator.rs crates/core/src/orchestrator.rs
git mv src-tauri/src/state.rs crates/core/src/state.rs
git mv src-tauri/src/session.rs crates/core/src/session.rs
git mv src-tauri/src/radio.rs crates/core/src/radio.rs
git mv src-tauri/src/lyrics.rs crates/core/src/lyrics.rs
git mv src-tauri/src/discord.rs crates/core/src/discord.rs
```

Add `pub mod orchestrator; pub mod state; pub mod session; pub mod radio; pub mod lyrics; pub mod discord;` to core's `lib.rs` and replace `mod ...;` with `use ryotunes_core::{...};` in the host. Run `cargo check -p ryotunes-core`.
Expected: errors only at `state.rs:15,54,328` (`AppHandle`), the ten `self.app.emit(...)` sites, the `tauri::async_runtime::spawn` sites in `state.rs` (`820`, `1314`, `1391`, `2066`) and `orchestrator.rs`, and `session.rs:13-15` plus `open_login`. `radio`, `lyrics` and `discord` need no edits beyond their `crate::` paths, which stay valid because their targets moved with them.

- [ ] **Step 2: Replace `app` with `sink` + `login` in `AppState`**

```rust
use std::sync::Arc;
use crate::host::{EventSink, LoginFlow, Paths};

pub struct AppState {
    // ...
    pub sink: Arc<dyn EventSink>,
    pub login: Arc<dyn LoginFlow>,
    pub paths: Paths,
    // ...
}

impl AppState {
    pub fn emit<T: serde::Serialize>(&self, event: &'static str, payload: T) {
        match serde_json::to_value(payload) {
            Ok(v) => self.sink.emit(event, v),
            Err(e) => tracing::warn!(event, error = %e, "event payload not serializable"),
        }
    }
}
```

Then every `let _ = self.app.emit("x", y);` becomes `self.emit("x", y);` (ten sites), `tauri::async_runtime::spawn` becomes `tokio::spawn`, and `AppState::new` takes `sink`, `login`, `paths` in place of `app`.

- [ ] **Step 3: Split the session**

`crates/core/src/session.rs` keeps `allowed_login_navigation`, its tests, `LOGIN_URL`, the cookie-to-`Session` application code, and gains:

```rust
impl AppState {
    /// Runs the host's interactive sign-in and applies the result exactly as `open_login` did.
    pub async fn sign_in(self: &Arc<Self>) {
        match self.login.sign_in().await {
            Ok(result) => self.apply_login(result).await,
            Err(crate::host::LoginError::Cancelled) => {}
            Err(e) => self.emit("login-error", e.to_string()),
        }
    }
}
```

where `apply_login(result: LoginResult)` is the tail of today's `open_login` (cookie harvest done, session written, `auth-changed`/`login-done`/`account-selection-required` emitted).

`src-tauri/src/login_webview.rs` keeps the `WebviewWindowBuilder` login window, the `on_navigation` allow-list (calling `ryotunes_core::session::allowed_login_navigation`), the `PageLoadEvent` cookie harvest, and implements:

```rust
pub struct TauriLogin { pub app: AppHandle }

#[async_trait::async_trait]
impl LoginFlow for TauriLogin {
    async fn sign_in(&self) -> Result<LoginResult, LoginError> {
        // today's open_login body up to the point where cookies are in hand,
        // returning them through a oneshot instead of touching AppState
    }
}
```

`commands::login_webview` becomes `state.sign_in().await`.

- [ ] **Step 4: Build, test, smoke the login and playback**

Run: `cargo check --workspace --locked && cargo test --workspace --locked && cargo fmt --all -- --check`
Expected: green; `session::tests` (the allow-list cases at old `session.rs:168-180`) run from core.

Run the app, sign out, sign in again through the account menu.
Expected: the Google window opens, closes on completion, `auth-changed` reaches the UI (avatar appears), a fresh track resolves with `client="WEB_REMIX"`.

- [ ] **Step 5: Commit**

```bash
git add -A crates/core src-tauri
git commit -m "core: move state, orchestrator and session; host implements LoginFlow"
```

---

### Task 6: Shrink the host to forwarders and run the release gates

**Files:**
- Modify: `src-tauri/src/commands.rs` (every handler forwards into `ryotunes_core`), `src-tauri/src/lib.rs` (setup builds `Paths`, the three trait objects, then `AppState::new`), `src-tauri/Cargo.toml` (drop dependencies now only used by core: `rusqlite`, `base64`, `regex`, `urlencoding`, `reqwest`, `souvlaki`, `tokio-tungstenite`, `rustls`, `discord-rich-presence`, `md-5`, `lofty`; keep `tauri*`, `webkit2gtk`, `ksni`, `libc`, `serde*`, `tokio`, `tracing*`, `async-trait`, `ryotunes-core`)
- Modify: `docs/ARCHITECTURE.md` (add the crate table from the spec's 4.1), `scripts/check-rust-structure.py` if it asserts the old module list
- Test: `scripts/release-check.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: the host as it will stay until phase 4: `commands.rs` contains no logic beyond argument shaping.

- [ ] **Step 1: Make every command a forwarder**

The pattern, applied to all 94 handlers (the compiler enforces completeness: any `crate::` path left in `commands.rs` fails to resolve):

```rust
#[tauri::command]
pub async fn search(state: St<'_>, query: String) -> Result<Vec<SongItem>, String> {
    state.search(&query).await.map_err(|e| e.to_string())
}
```

where the body that used to live in the command becomes `AppState::search` in core when it touched state, or stays a plain call when it already was one line. Handlers that need Tauri (`open_mini`, `close_mini`, `login_webview`, `open_external`, dialogs in `add_local_folder`/`export_playlist_file`/`import_playlist_file`) keep their Tauri calls and forward the data part.

- [ ] **Step 2: Run the structure and release checks**

Run: `python3 scripts/check-rust-structure.py && python3 scripts/check-source-shapes.py && scripts/release-check.sh`
Expected: green. If `check-rust-structure.py` enumerates `src-tauri/src` modules, update its list to the host's remaining files: `lib.rs main.rs commands.rs webview.rs host_sink.rs login_webview.rs local_scope.rs main_window.rs mini.rs tray.rs taskbar.rs ryoku_theme.rs`.

- [ ] **Step 3: Full gates and dependency audit**

Run: `cargo fmt --all -- --check && cargo test --workspace --locked && cargo check --workspace --locked && cargo tree -p ryotunes-core -i tauri`
Expected: green, and the last command errors with `did not match any packages`.

Run: `cargo tauri build --no-bundle && ls -la target/release/ryotunes`
Expected: builds; binary size within 5% of the previous release build.

- [ ] **Step 4: Measure that nothing regressed**

With the built binary: `RUST_LOG=info ./target/release/ryotunes`, play, scroll Home for 10 s, open lyrics, close the window while playing, reopen from the tray. Record with the baseline instruments (`top -b -d 5 -n 3 -p <pids>`, `/proc/<pid>/smaps_rollup`).
Expected: the same numbers as the 2026-09-04 baseline within noise (host ~3% + web ~2% playing; ~585 MB PSS); hibernation still destroys the main webview (`ps` shows the main `WebKitWebProcess` gone while playback continues).

- [ ] **Step 5: Commit**

```bash
git add -A src-tauri crates/core docs/ARCHITECTURE.md scripts
git commit -m "host: forward every command into ryotunes-core"
```

---

## Self-review

- Spec coverage (phase 1 only): 4.1 crate table (Tasks 1-6), 4.2 the three traits (Task 1, used in 3-5), `Paths` (Tasks 1, 4), `tokio::spawn` replacement (Tasks 3-5), behaviour parity gates (Global Constraints, Task 6 Step 4). Sections 4.3-4.4 (protocol, lifecycle), 5 (client), 6 daemon-side `JsBridge`, 7 and 8.2-8.4 are later phases by design.
- Placeholders: none; every code step shows the code or the exact substitution.
- Type consistency: `EventSink::emit(&self, &'static str, Value)` everywhere; `JsSession::clone_session` is defined in Task 1 and used in Task 3; `Paths::covers_dir` defined in Task 1 and used in Task 4; `AppState::emit` defined in Task 5 and used by the substitutions there.
