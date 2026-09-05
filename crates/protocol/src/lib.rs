//! The daemon's socket protocol. One JSON object per line in both directions.
pub mod wire;

pub use wire::{ErrorBody, Event, Incoming, Outgoing, Request, Response, PROTOCOL_VERSION};

use std::path::PathBuf;

/// `$XDG_RUNTIME_DIR/ryotunes/ryotunesd.sock`, or `/tmp/ryotunes-<uid>/ryotunesd.sock` without a
/// runtime dir (a bare TTY login). The directory is created by the daemon with mode 0700.
pub fn socket_path() -> PathBuf {
    let dir = std::env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from).unwrap_or_else(|| {
        std::env::temp_dir().join(format!("ryotunes-{}", unsafe { libc_uid() }))
    });
    dir.join("ryotunes").join("ryotunesd.sock")
}

// No libc dependency for one call: read the uid from the kernel.
unsafe fn libc_uid() -> u32 {
    std::fs::read_to_string("/proc/self/loginuid")
        .ok()
        .and_then(|s| s.trim().parse().ok())
        .unwrap_or(0)
}
