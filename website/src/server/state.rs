use axum::extract::FromRef;
use leptos::prelude::LeptosOptions;

/// Application state shared with Leptos SSR. The MLXRead product site has no
/// data layer or sessions, so this carries only what the framework needs. The
/// edge handler keeps the security headers
/// (CSP, X-Frame-Options, nosniff) but sets no cookies.
#[derive(Clone)]
pub struct AppState {
    pub leptos_options: LeptosOptions,
}

impl AppState {
    pub fn new(leptos_options: LeptosOptions) -> Self {
        Self { leptos_options }
    }
}

impl FromRef<AppState> for LeptosOptions {
    fn from_ref(input: &AppState) -> Self {
        input.leptos_options.clone()
    }
}
