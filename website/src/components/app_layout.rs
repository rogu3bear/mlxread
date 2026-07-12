use leptos::prelude::*;

/// Persistent header + footer wrapped around every page. Participates in SSR
/// and hydration. Nav links are in-page anchors, so they work before hydration.
#[component]
pub fn AppLayout(children: Children) -> impl IntoView {
    view! {
        <a class="skip-link" href="#how">"Skip to content"</a>
        <header class="topbar">
            <div class="topbar__inner">
                <a class="brand" href="/">
                    <img class="brand__mark" src="/app-icon.svg" alt="" width="26" height="26"/>
                    <span class="brand__name">"MLXRead"</span>
                </a>
                <nav class="nav">
                    <a class="nav__link" href="#how">"How it works"</a>
                    <a class="nav__link" href="#privacy">"Privacy"</a>
                    <a class="nav__link" href="#speed">"Speed"</a>
                    <a class="nav__link nav__link--cta" href="#install">"Build"</a>
                </nav>
            </div>
        </header>

        {children()}

        <footer class="footer">
            <div class="footer__inner">
                <div class="footer__brand">
                    <img class="brand__mark" src="/app-icon.svg" alt="" width="22" height="22"/>
                    <span class="mono">"MLXRead"</span>
                </div>
                <p class="footer__note muted">
                    "Local text-to-speech for macOS. MIT-licensed. Not affiliated with Apple. "
                    "Selected text never leaves your Mac."
                </p>
                <p class="footer__built mono muted">
                    "Built with Leptos, served from Cloudflare Workers."
                </p>
            </div>
        </footer>
    }
}
