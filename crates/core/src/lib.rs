//! Ryotunes playback core. Everything that is not a window lives here; the host (Tauri today, the
//! daemon tomorrow) supplies the three traits in [`host`].
pub mod host;

pub mod db;
pub mod http;
