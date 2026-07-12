use leptos::prelude::*;
use leptos_router::hooks::use_query_map;

use crate::components::home_page::REPO_URL;

const ISSUES_URL: &str = "https://github.com/rogu3bear/mlxread/issues";

/// Support + contact. Troubleshooting mirrors the README; the contact form is a
/// native same-origin POST to /api/contact (CSP form-action 'self'), which the
/// Pages worker forwards to the delivery worker and redirects back with
/// ?status=sent|error so the outcome renders server-side (works with JS off).
#[component]
pub fn SupportPage() -> impl IntoView {
    let query = use_query_map();
    let status = move || {
        query
            .read()
            .get("status")
            .map(|s| s.to_string())
            .unwrap_or_default()
    };
    let sent = move || status() == "sent";
    let errored = move || status() == "error";

    view! {
        <main class="shell">
            <article class="support band">
                <p class="eyebrow">"Support"</p>
                <h1>"Get it working — or get in touch."</h1>
                <p class="legal__lede">
                    "Most issues are one setting away. Start with the quick fixes and the "
                    <a href="/faq">"FAQ"</a>
                    "; if you're still stuck, send a message and it comes straight to the maintainer."
                </p>

                <section class="support__section">
                    <h2>"Quick fixes"</h2>
                    <div class="support__grid">
                        <Trouble title="⌥⎋ does nothing">
                            "The event tap needs Accessibility access. Grant it in System Settings → Privacy & Security → Accessibility, then hit "
                            <span class="mono">"Recheck"</span>
                            " in Settings → Permissions. If Apple's Speak Selection also uses ⌥⎋, reassign it."
                        </Trouble>
                        <Trouble title="\"No selected text was found\"">
                            "The frontmost app reported no selection. For apps without Accessibility text (some Electron apps, protected fields), enable the clipboard fallback in Settings → General."
                        </Trouble>
                        <Trouble title="Model download failed">
                            "Retry from Settings → Models — partial downloads are detected and re-fetched. Check free disk space (~0.6 GB for both models)."
                        </Trouble>
                        <Trouble title="First read is slow">
                            "That's the one-time model load. After the first read the model stays warm and time-to-first-word drops to a second or two."
                        </Trouble>
                        <Trouble title="No audio">
                            "Check the selected output device. The app reports \"audio device unavailable\" if the engine can't start — switch devices and try again."
                        </Trouble>
                        <Trouble title="Gatekeeper warning">
                            "You shouldn't see one — the release is notarized. If you do, you likely have an old build; download the latest and replace it."
                        </Trouble>
                    </div>
                </section>

                <section class="support__section">
                    <h2>"More help"</h2>
                    <ul class="support__links">
                        <li>
                            <a href="/faq">"FAQ"</a>
                            " — the common questions, answered in detail."
                        </li>
                        <li>
                            <b>"In-app reporting"</b>
                            " — Settings → Report attaches a privacy-safe debug bundle (never your text) and sends it to the maintainer."
                        </li>
                        <li>
                            <a href=ISSUES_URL rel="noopener" target="_blank">"GitHub issues"</a>
                            " — for bugs and feature requests in the open. "
                            <a href=REPO_URL rel="noopener" target="_blank">"Source"</a>
                            " is public."
                        </li>
                    </ul>
                </section>

                <section class="support__section" id="contact">
                    <h2>"Send a message"</h2>
                    <p class="band__sub">
                        "Questions, bugs, ideas, or just hello. It goes directly to me — no newsletter, no third parties, no bots."
                    </p>

                    <Show when=sent>
                        <div class="banner banner--ok" role="status">
                            <span class="banner__mark" aria-hidden="true"></span>
                            <div>
                                <b>"Message sent."</b>
                                " Thanks — I read every one and will reply to the address you gave."
                            </div>
                        </div>
                    </Show>
                    <Show when=errored>
                        <div class="banner banner--err" role="alert">
                            <span class="banner__mark" aria-hidden="true"></span>
                            <div>
                                <b>"That didn't go through."</b>
                                " Please try again in a moment, or open an issue on "
                                <a href=ISSUES_URL rel="noopener" target="_blank">"GitHub"</a>
                                "."
                            </div>
                        </div>
                    </Show>
                    <form class="contact" method="post" action="/api/contact">
                        <div class="contact__row">
                            <label class="field">
                                <span class="field__label">"Name"</span>
                                <input
                                    class="field__input"
                                    type="text"
                                    name="name"
                                    autocomplete="name"
                                    maxlength="200"
                                    placeholder="Optional"
                                />
                            </label>
                            <label class="field">
                                <span class="field__label">"Email"</span>
                                <input
                                    class="field__input"
                                    type="email"
                                    name="email"
                                    autocomplete="email"
                                    required=true
                                    maxlength="254"
                                    placeholder="you@example.com"
                                />
                            </label>
                        </div>
                        <label class="field">
                            <span class="field__label">"Topic"</span>
                            <select class="field__input" name="topic">
                                <option value="general">"General"</option>
                                <option value="bug">"Bug report"</option>
                                <option value="feature">"Feature idea"</option>
                                <option value="privacy">"Privacy"</option>
                                <option value="other">"Other"</option>
                            </select>
                        </label>
                        <label class="field">
                            <span class="field__label">"Message"</span>
                            <textarea
                                class="field__input field__input--area"
                                name="message"
                                rows="6"
                                required=true
                                maxlength="6000"
                                placeholder="What's on your mind?"
                            ></textarea>
                        </label>
                        // Honeypot: hidden from humans, bots fill it and get dropped.
                        <input
                            class="hp"
                            type="text"
                            name="company"
                            tabindex="-1"
                            autocomplete="off"
                            aria-hidden="true"
                        />
                        <div class="contact__actions">
                            <button class="btn btn--primary" type="submit">"Send message"</button>
                            <span class="contact__note muted">
                                "Sent over HTTPS. Your address is used only to reply."
                            </span>
                        </div>
                    </form>
                </section>

                <a class="btn btn--ghost legal__back" href="/">"← Back to MLXRead"</a>
            </article>
        </main>
    }
}

#[component]
fn Trouble(#[prop(into)] title: String, children: Children) -> impl IntoView {
    view! {
        <div class="trouble">
            <h3 class="trouble__title">{title}</h3>
            <p class="trouble__body">{children()}</p>
        </div>
    }
}
