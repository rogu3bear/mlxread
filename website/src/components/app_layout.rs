use leptos::prelude::*;
use leptos_router::components::A;

use crate::components::home_page::REPO_URL;

const AUTHOR_URL: &str = "https://jkca.me";
const AUTHOR_GITHUB: &str = "https://github.com/rogu3bear";

/// Persistent, progressively enhanced navigation for every route. Route
/// changes use Leptos Router; same-document section jumps remain native links.
#[component]
pub fn AppLayout(children: Children) -> impl IntoView {
    view! {
        <a class="skip-link" href="#main-content">"Skip to content"</a>
        <header class="topbar">
            <div class="topbar__inner">
                <A href="/" exact=true attr:class="brand">
                    <img class="brand__mark" src="/app-icon.svg" alt="" width="26" height="26"/>
                    <span class="brand__name">"MLXRead"</span>
                </A>
                <nav class="nav" aria-label="Primary navigation">
                    <a class="nav__link" href="/#how">"How it works"</a>
                    <A href="/privacy" attr:class="nav__link">"Privacy"</A>
                    <A href="/faq" attr:class="nav__link">"FAQ"</A>
                    <A href="/support" attr:class="nav__link">"Support"</A>
                    <A href="/get-started" attr:class="nav__link nav__link--cta">"Get started"</A>
                </nav>
            </div>
        </header>

        <div id="main-content" tabindex="-1">{children()}</div>

        <footer class="footer">
            <div class="footer__inner">
                <div class="footer__top">
                    <A href="/" exact=true attr:class="footer__brand">
                        <img class="brand__mark" src="/app-icon.svg" alt="" width="22" height="22"/>
                        <span class="mono">"MLXRead"</span>
                    </A>
                    <nav class="footer__links" aria-label="Footer navigation">
                        <A href="/get-started">"Get started"</A>
                        <A href="/faq">"FAQ"</A>
                        <A href="/support">"Support"</A>
                        <a href=REPO_URL rel="noopener" target="_blank">"Source"</a>
                        <A href="/privacy">"Privacy"</A>
                        <A href="/terms">"Terms"</A>
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
