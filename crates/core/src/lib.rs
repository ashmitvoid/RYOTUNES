//! Ryotunes playback core. Everything that is not a window lives here; the host (Tauri today, the
//! daemon tomorrow) supplies the three traits in [`host`].
pub mod host;

pub mod cipher;
pub mod db;
pub mod http;
pub mod listentogether;
pub mod media;
pub mod potoken;
