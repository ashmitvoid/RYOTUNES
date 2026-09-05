mod gtk_thread;
mod js;
mod login;
mod server;
mod sink;

fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "warn".into()),
        )
        .init();
    eprintln!("ryotunesd: not wired yet (Task 4)");
}
