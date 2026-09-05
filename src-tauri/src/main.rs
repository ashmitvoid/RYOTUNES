// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    #[cfg(target_os = "linux")]
    if daemon::defer_to_live_daemon() {
        return;
    }
    app_lib::run();
}

/// The Tauri app and `ryotunesd` each own a libmpv player. Launching this binary while a daemon is
/// playing (the desktop's `ryotunes` keybind, the dock, the desktop entry, all of which predate the
/// daemon) started a second engine over the first, so two songs played at once. `/usr/bin/ryotunes`
/// therefore asks a live daemon to `show` (raise its client, or open `ryotunes-qml`) and exits;
/// only with no daemon running does it become the standalone app it always was.
#[cfg(target_os = "linux")]
mod daemon {
    use std::io::{BufRead, BufReader, Write};
    use std::os::fd::AsRawFd;
    use std::os::unix::net::UnixStream;

    /// True when a daemon is running and took the hand-off. Liveness is the daemon's own instance
    /// lock (`ryotunesd.sock.lock`, held with flock for its lifetime), never the socket: systemd
    /// keeps `ryotunesd.sock` listening while the daemon is idle-exited, and connecting to it
    /// would start a daemon just to be asked "show", which would then open a client the user never
    /// asked for.
    pub fn defer_to_live_daemon() -> bool {
        let sock = ryotunes_protocol::socket_path();
        let Some(dir) = sock.parent() else { return false };
        let Ok(lock) =
            std::fs::OpenOptions::new().write(true).open(dir.join("ryotunesd.sock.lock"))
        else {
            return false;
        };
        // Safe: a plain advisory-lock syscall on a fd we own.
        let rc = unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) };
        if rc == 0 {
            // We got the lock, so nobody holds it: no daemon. Release it before the app starts.
            unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_UN) };
            return false;
        }
        if std::io::Error::last_os_error().raw_os_error() != Some(libc::EWOULDBLOCK) {
            return false;
        }
        match show(&sock) {
            Ok(reply) => {
                tracing_lite(&format!("ryotunesd is running; asked it to show ({reply})"));
                true
            }
            Err(e) => {
                tracing_lite(&format!(
                    "ryotunesd holds its lock but `show` failed: {e}; starting the app"
                ));
                false
            }
        }
    }

    fn show(sock: &std::path::Path) -> std::io::Result<String> {
        let mut stream = UnixStream::connect(sock)?;
        stream.set_read_timeout(Some(std::time::Duration::from_secs(5)))?;
        stream.write_all(b"{\"id\":1,\"method\":\"show\"}\n")?;
        let mut line = String::new();
        BufReader::new(stream).read_line(&mut line)?;
        Ok(line.trim_end().to_string())
    }

    // The tracing subscriber is installed inside `app_lib::run`, which this path never reaches.
    fn tracing_lite(msg: &str) {
        eprintln!("ryotunes: {msg}");
    }
}
