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
