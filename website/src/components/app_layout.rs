use leptos::prelude::*;

use crate::components::home_page::REPO_URL;

const AUTHOR_URL: &str = "https://jkca.me";
const AUTHOR_GITHUB: &str = "https://github.com/rogu3bear";

/// Persistent header + footer wrapped around every page. Participates in SSR
/// and hydration. Home-section links use `/#anchor` so they work from any
/// route (e.g. the /privacy and /terms pages).
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
                    <a class="nav__link" href="/#how">"How it works"</a>
                    <a class="nav__link" href="/#privacy">"Privacy"</a>
                    <a class="nav__link" href="/#speed">"Speed"</a>
                    <a class="nav__link nav__link--cta" href="/#install">"Download"</a>
                </nav>
            </div>
        </header>

        {children()}

        <footer class="footer">
            <div class="footer__inner">
                <div class="footer__top">
                    <a class="footer__brand" href="/">
                        <img class="brand__mark" src="/app-icon.svg" alt="" width="22" height="22"/>
                        <span class="mono">"MLXRead"</span>
                    </a>
                    <nav class="footer__links">
                        <a href="/#install">"Download"</a>
                        <a href=REPO_URL rel="noopener" target="_blank">"Source"</a>
                        <a href="/privacy">"Privacy"</a>
                        <a href="/terms">"Terms"</a>
                    </nav>
                </div>
                <p class="footer__note muted">
                    "Local text-to-speech for macOS. MIT-licensed. Not affiliated with Apple. "
                    "Selected text never leaves your Mac."
                </p>
                <div class="footer__by mono muted">
                    <span>
                        "By "
                        <a href=AUTHOR_URL rel="noopener" target="_blank">"jkca.me"</a>
                        " · "
                        <a href=AUTHOR_GITHUB rel="noopener" target="_blank">"github.com/rogu3bear"</a>
                    </span>
                    <span>"Built with Leptos, served from Cloudflare."</span>
                </div>
            </div>
        </footer>
    }
}
