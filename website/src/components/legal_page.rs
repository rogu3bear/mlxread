use leptos::prelude::*;
use leptos_router::components::A;

use crate::components::home_page::REPO_URL;
use crate::components::page_meta::PageMeta;

/// Privacy policy. MLXRead collects nothing; this page states that plainly.
#[component]
pub fn PrivacyPage() -> impl IntoView {
    view! {
        <PageMeta
            title="MLXRead privacy policy"
            description="MLXRead synthesizes selected text locally, stores no reading content, and includes no accounts, analytics, or trackers."
            path="/privacy"
        />
        <main class="shell">
            <article class="legal band">
                <p class="eyebrow">"Privacy Policy"</p>
                <h1>"MLXRead collects nothing."</h1>
                <p class="legal__updated mono muted">"Last updated: July 2026"</p>

                <p class="legal__lede">
                    "MLXRead is a local macOS app that reads your selected text aloud with an on-device model. It has no account system, no analytics, and no server. There is nothing for us to collect, because your data never reaches us."
                </p>

                <Section title="The app">
                    <Item>
                        "Selected text is held in memory only while it is being read, and is never written to disk."
                    </Item>
                    <Item>
                        "Selected text is never logged. The app's logs record lengths and timings only — never content."
                    </Item>
                    <Item>
                        "There is no analytics, no crash-reporting SDK, and no account."
                    </Item>
                    <Item>
                        "Synthesis runs in-process on your Mac's GPU. Selected text is never transmitted anywhere."
                    </Item>
                    <Item>
                        "The network is used only to download a voice model the first time you request one, and to check for app updates. After a model is downloaded, MLXRead works fully offline."
                    </Item>
                    <Item>
                        "App updates are delivered over HTTPS from GitHub and cryptographically verified (EdDSA) before installing. The update check sends only what a normal file download sends."
                    </Item>
                </Section>

                <Section title="This website">
                    <Item>"This site sets no cookies and runs no analytics or trackers."</Item>
                    <Item>
                        "It is served from Cloudflare, which processes standard request logs (such as IP address) for security and delivery, per Cloudflare's own policies. We do not add to or retain that data."
                    </Item>
                    <Item>
                        "The download links point to GitHub Releases; downloading is subject to GitHub's policies."
                    </Item>
                </Section>

                <Section title="Contact">
                    <Item>
                        "Questions? The project is open source — open an issue on "
                        <a href=REPO_URL rel="noopener" target="_blank">"GitHub"</a>"."
                    </Item>
                </Section>

                <A href="/" attr:class="btn btn--ghost legal__back">"← Back to MLXRead"</A>
            </article>
        </main>
    }
}

/// Terms of use for a free, MIT-licensed open-source app.
#[component]
pub fn TermsPage() -> impl IntoView {
    view! {
        <PageMeta
            title="MLXRead terms of use"
            description="Terms for using the free, MIT-licensed MLXRead macOS application."
            path="/terms"
        />
        <main class="shell">
            <article class="legal band">
                <p class="eyebrow">"Terms of Use"</p>
                <h1>"Free software, provided as-is."</h1>
                <p class="legal__updated mono muted">"Last updated: July 2026"</p>

                <p class="legal__lede">
                    "MLXRead is free and open-source software released under the MIT License. By downloading, building, or using it, you agree to these terms."
                </p>

                <Section title="License">
                    <Item>
                        "MLXRead is licensed under the MIT License. You may use, copy, modify, and redistribute it under those terms. The full license text ships with the source and the app."
                    </Item>
                    <Item>
                        "Third-party components (the MLX libraries, Sparkle, and the downloaded voice models) are covered by their own licenses, listed in the project's THIRD_PARTY_NOTICES."
                    </Item>
                </Section>

                <Section title="No warranty">
                    <Item>
                        "The software is provided \"as is\", without warranty of any kind, express or implied. The authors are not liable for any claim, damages, or other liability arising from its use, to the fullest extent permitted by law."
                    </Item>
                    <Item>
                        "MLXRead requires macOS Accessibility permission to read the current selection and to receive its keyboard shortcut. You grant that permission yourself; the app never changes your system settings for you."
                    </Item>
                </Section>

                <Section title="Acceptable use">
                    <Item>
                        "Use MLXRead only with text you have the right to access. You are responsible for how you use it."
                    </Item>
                    <Item>
                        "MLXRead is not affiliated with, endorsed by, or sponsored by Apple. \"macOS\" and \"Apple Silicon\" are trademarks of Apple Inc."
                    </Item>
                </Section>

                <A href="/" attr:class="btn btn--ghost legal__back">"← Back to MLXRead"</A>
            </article>
        </main>
    }
}

#[component]
fn Section(#[prop(into)] title: String, children: Children) -> impl IntoView {
    view! {
        <section class="legal__section">
            <h2>{title}</h2>
            <ul class="legal__list">{children()}</ul>
        </section>
    }
}

#[component]
fn Item(children: Children) -> impl IntoView {
    view! { <li>{children()}</li> }
}
