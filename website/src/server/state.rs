use axum::extract::FromRef;
use leptos::prelude::LeptosOptions;

/// Application state shared with Leptos SSR. The MLXRead site is a static
/// marketing/demo surface with no data layer, so this carries only what the
/// framework needs plus the per-request session id that backs the hardened
/// cookie the edge handler still sets (see `lib.rs`). Keeping the session and
/// security headers preserves the template's posture even without a backend.
#[derive(Clone)]
pub struct AppState {
    pub leptos_options: LeptosOptions,
    pub session_id: std::sync::Arc<str>,
}

impl AppState {
    pub fn new(leptos_options: LeptosOptions, session_id: String) -> Self {
        Self {
            leptos_options,
            session_id: std::sync::Arc::<str>::from(session_id),
        }
    }
}

impl FromRef<AppState> for LeptosOptions {
    fn from_ref(input: &AppState) -> Self {
        input.leptos_options.clone()
    }
}
