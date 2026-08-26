# Security and privacy

Ryotunes stores account/session state locally in its Tauri application-data directory. Do not attach that directory, SQLite database, browser session data, or raw application logs to public bug reports.

For Discord support, use `./scripts/diagnostics.sh`. It reports platform and dependency versions while intentionally excluding account details, cookies, tokens, local media paths, hostnames, and configured network endpoints.

If you discover a bug that exposes credentials or session data, avoid posting the secret publicly. Revoke or sign out the affected session first, then report the issue with sanitized reproduction steps.
