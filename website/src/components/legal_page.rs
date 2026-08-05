use leptos::prelude::*;
use leptos_router::components::A;

use crate::components::home_page::REPO_URL;
use crate::components::page_meta::PageMeta;

/// Privacy policy. Reading content stays local; support/report data is explicit.
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
                <h1>"Your reading content stays on your Mac."</h1>
                <p class="legal__updated mono muted">"Last updated: August 2026"</p>

                <p class="legal__lede">
                    "MLXRead reads selected text with an on-device model. Selected and spoken text is never transmitted, stored by the website, or included in a problem report. Networked support and delivery surfaces handle only the information described below."
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
                        "Network use is limited to model and pronunciation assets, configured update checks, and problem reports you explicitly send. Local reading works offline after required assets are cached."
                    </Item>
                    <Item>
                        "When a release update feed is configured, Sparkle uses HTTPS and verifies each update's EdDSA signature before installing. Source builds with placeholder feed settings keep updates inactive."
                    </Item>
                </Section>

                <Section title="This website">
                    <Item>"This site sets no cookies and runs no analytics or trackers."</Item>
                    <Item>
                        "It is served from Cloudflare, which may process standard request metadata such as IP address for security and delivery under Cloudflare's policies. The site adds no analytics or behavioral tracking."
                    </Item>
                    <Item>
                        "If you use the support form, its name, email, topic, message, and standard request metadata are delivered to the maintainer. Do not paste selected or spoken text into the form."
                    </Item>
                    <Item>
                        "The download links point to GitHub Releases; downloading is subject to GitHub's policies."
                    </Item>
                </Section>

                <Section title="Problem reports">
                    <Item>
                        "An in-app report sends the email and description you enter, app and Mac diagnostic metadata, and recent MLXRead logs. It never reads or includes selected or spoken text."
                    </Item>
                    <Item>
                        "The delivery service stores report bundles behind high-entropy bearer links. Anyone who obtains a link can retrieve that bundle; the current service does not assert automatic deletion."
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
