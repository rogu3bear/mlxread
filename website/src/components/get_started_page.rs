use leptos::prelude::*;
use leptos_router::components::A;

use crate::components::home_page::DOWNLOAD_URL;
use crate::components::page_meta::PageMeta;
use crate::components::widgets::OptEsc;

#[component]
pub fn GetStartedPage() -> impl IntoView {
    let prerequisites = [
        ("Mac", "Apple Silicon (M1 or newer)"),
        ("System", "macOS 14 or newer"),
        ("Storage", "About 0.6 GB for both voices"),
    ];

    view! {
        <PageMeta
            title="Get started with MLXRead"
            description="Install MLXRead, grant Accessibility access, download a local voice, and hear your first selection on an Apple Silicon Mac."
            path="/get-started"
        />
        <main class="shell">
            <article class="start band">
                <header class="start__hero">
                    <p class="eyebrow">"Your first local read"</p>
                    <h1>"From download to listening in a few minutes."</h1>
                    <p class="legal__lede">
                        "MLXRead reads selected text with a model running on your Mac. The setup is short, explicit, and reversible."
                    </p>
                    <div class="hero__actions">
                        <a class="btn btn--primary" href=DOWNLOAD_URL rel="noopener">
                            "Download MLXRead"
                        </a>
                        <A href="/faq" attr:class="btn btn--ghost">"Read the FAQ"</A>
                    </div>
                    <p class="hero__foot mono muted">
                        "Signed & notarized · macOS 14+ · Apple Silicon · ~30 MB DMG"
                    </p>
                </header>

                <section class="start__section" aria-labelledby="before-download">
                    <h2 id="before-download">"Before you download"</h2>
                    <div class="requirements">
                        {prerequisites
                            .into_iter()
                            .map(|(label, value)| {
                                view! {
                                    <div class="requirement">
                                        <span class="requirement__label mono muted">{label}</span>
                                        <strong>{value}</strong>
                                    </div>
                                }
                            })
                            .collect_view()}
                    </div>
                </section>

                <section class="start__section" aria-labelledby="install-steps">
                    <h2 id="install-steps">"Install and hear your first selection"</h2>
                    <ol class="start-steps">
                        <StartStep number="01" title="Put MLXRead in Applications">
                            "Open the downloaded DMG, drag MLXRead into Applications, eject the installer, and launch the app. Both the installer and app are Developer ID–signed and notarized by Apple."
                        </StartStep>
                        <StartStep number="02" title="Grant Accessibility access">
                            "When macOS opens Privacy & Security → Accessibility, enable MLXRead. This permission lets the app receive the global shortcut and read the selection from the frontmost app. It does not grant network access."
                        </StartStep>
                        <StartStep number="03" title="Choose one local voice">
                            "Open Settings → Models. Choose Kokoro for 54 voices across several languages, or Soprano for the fastest English reading. The model downloads once and stays on your Mac."
                        </StartStep>
                        <StartStep number="04" title="Resolve the shortcut once">
                            "If Apple's built-in Speak Selection also uses Option-Escape, reassign it under System Settings → Accessibility → Spoken Content. MLXRead will not change that setting for you."
                        </StartStep>
                        <StartStep number="05" title="Select, press, listen">
                            "Select a sentence in Safari, Notes, Mail, Xcode, or a text-layer PDF. Press "
                            <OptEsc/>
                            ". Press it again to stop immediately."
                        </StartStep>
                    </ol>
                </section>

                <section class="start__section start__recovery" aria-labelledby="not-working">
                    <div>
                        <p class="eyebrow">"If the first read does not start"</p>
                        <h2 id="not-working">"Check permission, model, then selection."</h2>
                        <p class="band__sub">
                            "Settings → Permissions shows whether Accessibility and the shortcut tap are active. Settings → Models shows whether a voice is ready. Secure fields intentionally cannot be read."
                        </p>
                    </div>
                    <div class="start__recovery-actions">
                        <A href="/support" attr:class="btn btn--primary">"Troubleshoot setup"</A>
                        <A href="/faq" attr:class="btn btn--ghost">"Common questions"</A>
                    </div>
                </section>
            </article>
        </main>
    }
}

#[component]
fn StartStep(
    #[prop(into)] number: String,
    #[prop(into)] title: String,
    children: Children,
) -> impl IntoView {
    view! {
        <li class="start-step">
            <span class="start-step__number mono">{number}</span>
            <div>
                <h3>{title}</h3>
                <p>{children()}</p>
            </div>
        </li>
    }
}
