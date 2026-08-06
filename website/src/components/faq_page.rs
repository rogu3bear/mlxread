use leptos::prelude::*;
use leptos_router::components::A;

use crate::components::home_page::REPO_URL;
use crate::components::page_meta::PageMeta;

/// Frequently asked questions. Answers are grounded in the real app behavior
/// (see README / docs), not marketing. Uses native <details> for a zero-JS,
/// CSP-safe accordion.
#[component]
pub fn FaqPage() -> impl IntoView {
    view! {
        <PageMeta
            title="MLXRead FAQ"
            description="Answers about MLXRead privacy, voices, Accessibility permission, supported Macs, updates, and troubleshooting."
            path="/faq"
        />
        <main class="shell">
            <article class="faq band">
                <p class="eyebrow">"FAQ"</p>
                <h1>"Questions, answered."</h1>
                <p class="legal__lede">
                    "The short version: it runs on your Mac, it reads your selection aloud, and your text never leaves the machine. The details are below."
                </p>

                <div class="faq__list">
                    <Faq q="Is my text actually private?">
                        <p>
                            "Yes. The selection is synthesized on-device by the MLX model, held in memory only while it is being read, and "
                            <b>"never written to disk, never logged, and never sent anywhere"</b>
                            ". The logs record lengths and timings only — never content. There are no analytics, no crash SDK, and no account."
                        </p>
                        <p class="faq__link">
                            <A href="/privacy">"Read the full privacy policy →"</A>
                        </p>
                    </Faq>

                    <Faq q="Does it work offline?">
                        <p>
                            "After you download a voice model once — and Kokoro fetches a few small pronunciation assets on its first synthesis — everything runs offline. The network is used only for that initial model download and for app-update checks."
                        </p>
                    </Faq>

                    <Faq q="Kokoro or Soprano — which model should I use?">
                        <p>
                            <b>"Kokoro (82M)"</b>
                            " is the default: 54 voices across several languages, natural prosody. "
                            <b>"Soprano (80M)"</b>
                            " is faster and English-only, with a single voice. Either one alone is enough; together they need about 0.6 GB. Pick Kokoro for range, Soprano for the quickest time-to-first-word."
                        </p>
                    </Faq>

                    <Faq q="I press ⌥⎋ and nothing happens.">
                        <p>
                            "The shortcut needs Accessibility permission — it powers both reading the selection and the keyboard tap. Grant it under System Settings → Privacy & Security → Accessibility, then use "
                            <span class="mono">"Recheck"</span>
                            " in Settings → Permissions, which also shows whether the ⌥⎋ tap is actually installed."
                        </p>
                        <p>
                            "If Apple's built-in "
                            <b>"Speak selection"</b>
                            " is also assigned to ⌥⎋, disable or reassign it under System Settings → Accessibility → Spoken Content. MLXRead won't change that setting for you."
                        </p>
                    </Faq>

                    <Faq q="Why does it need Accessibility permission?">
                        <p>
                            "Two reasons: to read the current selection from the frontmost app through the Accessibility API, and to receive the global ⌥⎋ shortcut. MLXRead monitors the grant continuously — if you revoke it, the app removes its keyboard tap and stops any active reading immediately."
                        </p>
                    </Faq>

                    <Faq q="Can I make it always on?">
                        <p>
                            "Yes. Turn on "
                            <b>"Launch at login"</b>
                            " in Settings → General (or from the menu-bar menu) and MLXRead starts automatically and stays in the menu bar — no Dock icon, always a keystroke away. That is the always-on mode."
                        </p>
                    </Faq>

                    <Faq q="Is it signed and notarized? Will Gatekeeper complain?">
                        <p>
                            "The release is Developer ID–signed, runs under the hardened runtime, and is "
                            <b>"notarized by Apple"</b>
                            ". Open the DMG, drag MLXRead to Applications, eject the installer, and launch it. macOS may show its normal first-open confirmation for an internet download, but it should not block the app as an unidentified developer."
                        </p>
                    </Faq>

                    <Faq q="How does it update?">
                        <p>
                            "Automatically, via Sparkle 2 with "
                            <b>"EdDSA-signed appcasts over HTTPS"</b>
                            " — every update is cryptographically verified before it installs. You can also check manually from the menu bar (Check for Updates…) or Settings → General."
                        </p>
                    </Faq>

                    <Faq q="Which Macs, and how much disk?">
                        <p>
                            "An Apple Silicon Mac running macOS 14 or newer. Budget about 0.6 GB for both voice models; either one alone is enough."
                        </p>
                    </Faq>

                    <Faq q="Can it read PDFs, or text in any app?">
                        <p>
                            "It reads the selection from most apps through the Accessibility API, with a clipboard-preserving ⌘C fallback for apps that don't expose their selection. PDF viewers must surface a text layer or respond to ⌘C. Secure input fields (password boxes) intentionally block capture."
                        </p>
                    </Faq>

                    <Faq q="What languages and voices are there?">
                        <p>
                            "Kokoro ships 54 voices across several languages; Soprano is a single English voice. Choose the voice and speed (0.5–2×) in Settings → Voice."
                        </p>
                    </Faq>

                    <Faq q="How do I report a bug or ask for a feature?">
                        <p>
                            "Use "
                            <b>"Settings → Report"</b>
                            " inside the app — it attaches a privacy-safe debug bundle (never your text). You can also open an issue on "
                            <a href=REPO_URL rel="noopener" target="_blank">"GitHub"</a>
                            " or use the form on the "
                            <A href="/support">"Support"</A>
                            " page."
                        </p>
                    </Faq>

                    <Faq q="How do I uninstall it?">
                        <p>
                            "Quit MLXRead, then drag it from Applications to the Trash. To remove the downloaded models too, delete "
                            <span class="mono">"~/Library/Application Support/MLXRead"</span>
                            ". Turning off Launch at login first is tidy, though it is cleared automatically when the app is removed."
                        </p>
                    </Faq>

                    <Faq q="Is it really free?">
                        <p>
                            "Yes — MIT-licensed and fully open source. No accounts, no paid tiers, no telemetry. You can read every line and build it yourself."
                        </p>
                    </Faq>
                </div>

                <div class="faq__more">
                    <p>
                        "Didn't find it? "
                        <A href="/support" attr:class="accent">"Get support or send a message →"</A>
                    </p>
                </div>

                <A href="/" attr:class="btn btn--ghost legal__back">"← Back to MLXRead"</A>
            </article>
        </main>
    }
}

#[component]
fn Faq(#[prop(into)] q: String, children: Children) -> impl IntoView {
    view! {
        <details class="faq__item">
            <summary class="faq__q">
                <span>{q}</span>
                <span class="faq__marker" aria-hidden="true"></span>
            </summary>
            <div class="faq__a">{children()}</div>
        </details>
    }
}
