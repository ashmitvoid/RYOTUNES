mod app;
mod gtk_thread;
mod js;
mod login;
mod methods;
mod server;
mod sink;

use std::os::unix::io::AsRawFd;
use std::path::Path;
use std::sync::Arc;

fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "warn".into()),
        )
        .init();

    let path = ryotunes_protocol::socket_path();
    // Task 5 replaces this bare flock with the single-instance show-and-exit handshake.
    let lock = hold_lock(&path)?;

    let rt = tokio::runtime::Builder::new_multi_thread().enable_all().build()?;
    let gtk = gtk_thread::Gtk::start();
    let sink = Arc::new(sink::SocketSink::default());
    let js: Arc<dyn ryotunes_core::host::JsBridge> = Arc::new(js::GtkJs::new(gtk.clone()));
    let login: Arc<dyn ryotunes_core::host::LoginFlow> =
        Arc::new(login::GtkLogin::new(gtk.clone()));

    rt.block_on(async {
        let (state, events, media_rx, lt_rx) =
            app::build(app::paths(), sink.clone(), js, login, &tokio::runtime::Handle::current())?;
        app::spawn_pumps(state.clone(), events, media_rx, lt_rx, sink.clone());

        let (quit_tx, mut quit_rx) = tokio::sync::mpsc::unbounded_channel();
        let server = server::Server::bind(&path, sink.clone())?;
        let methods = Arc::new(methods::Methods { state: state.clone(), quit: quit_tx });
        tokio::select! {
            _ = server.run(methods) => {}
            _ = quit_rx.recv() => {}
            _ = tokio::signal::ctrl_c() => {}
        }
        // Explicit teardown: stop mpv, flush the resume position, unregister MPRIS, drop Discord and
        // leave any Listen Together room — exactly what `main_window::request_quit` runs today.
        state.shutdown_for_quit().await;
        Ok::<(), anyhow::Error>(())
    })?;

    drop(lock);
    let _ = std::fs::remove_file(&path);
    Ok(())
}

/// Hold `ryotunesd.sock.lock` under `flock(LOCK_EX | LOCK_NB)` for the process lifetime, so a second
/// daemon cannot fight this one over the shared SQLite/mpv state. The returned handle keeps the
/// advisory lock; dropping it (at exit) releases it.
fn hold_lock(path: &Path) -> anyhow::Result<std::fs::File> {
    let dir = path.parent().expect("socket path has a parent");
    std::fs::create_dir_all(dir)?;
    let lock_path = dir.join("ryotunesd.sock.lock");
    let file =
        std::fs::OpenOptions::new().create(true).truncate(false).write(true).open(&lock_path)?;
    // Safe: a plain advisory-lock syscall on a fd we own.
    let rc = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) };
    if rc != 0 {
        anyhow::bail!("another ryotunesd already holds {}", lock_path.display());
    }
    Ok(file)
}
