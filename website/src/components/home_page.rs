use std::time::Duration;

use leptos::prelude::*;
use leptos_router::components::A;

use crate::components::page_meta::PageMeta;
use crate::components::widgets::{OptEsc, Waveform};

/// Source home and the signed-release download. Update the slug in one place.
pub const REPO_URL: &str = "https://github.com/rogu3bear/mlxread";
/// The latest signed .app zip from GitHub Releases (stable "latest" URL).
pub const DOWNLOAD_URL: &str =
    "https://github.com/rogu3bear/mlxread/releases/latest/download/MLXRead.zip";

#[derive(Clone, Copy, PartialEq, Eq)]
enum Phase {
    Idle,
    Capturing,
    Generating,
    Speaking,
}

impl Phase {
    fn status(self) -> &'static str {
        match self {
            Phase::Idle => "Idle",
            Phase::Capturing => "Capturing selection",
            Phase::Generating => "Generating",
            Phase::Speaking => "Speaking",
        }
    }

    fn index(self) -> usize {
        match self {
            Phase::Idle => 0,
            Phase::Capturing => 1,
            Phase::Generating => 2,
            Phase::Speaking => 3,
        }
    }
}

#[component]
pub fn HomePage() -> impl IntoView {
    view! {
        <PageMeta
            title="MLXRead — local, private speak selection for macOS"
            description="Press Option-Escape in any Mac app to hear selected text read aloud by a local MLX model. Nothing leaves your Mac."
            path="/"
        />
        <main class="shell">
            <HeroDemo/>
            <HowItWorks/>
            <Privacy/>
            <Performance/>
            <Reach/>
            <OpenSource/>
            <ClosingCta/>
        </main>
    }
}

#[component]
fn HeroDemo() -> impl IntoView {
    let phase = RwSignal::new(Phase::Idle);
    // Epoch cancels stale scheduled transitions — the same generation-id guard
    // the real coordinator uses so a second press can never be overtaken by a
    // pending step from the first.
    let epoch = RwSignal::new(0u32);

    let toggle = move |_| {
        if phase.get() == Phase::Idle {
            let current = epoch.get().wrapping_add(1);
            epoch.set(current);
            phase.set(Phase::Capturing);
            set_timeout(
                move || {
                    if epoch.get() != current {
                        return;
                    }
                    phase.set(Phase::Generating);
                    set_timeout(
                        move || {
                            if epoch.get() != current {
                                return;
                            }
                            phase.set(Phase::Speaking);
                            set_timeout(
                                move || {
                                    if epoch.get() == current {
                                        phase.set(Phase::Idle);
                                    }
                                },
                                Duration::from_millis(5200),
                            );
                        },
                        Duration::from_millis(950),
                    );
                },
                Duration::from_millis(650),
            );
        } else {
            // Second press = stop immediately (invalidate pending steps).
            epoch.update(|e| *e = e.wrapping_add(1));
            phase.set(Phase::Idle);
        }
    };

    let is_speaking = Signal::derive(move || phase.get() == Phase::Speaking);
    let is_running = Signal::derive(move || phase.get() != Phase::Idle);
    let selecting = Signal::derive(move || phase.get() != Phase::Idle);

    view! {
        <section class="hero">
            <div class="hero__copy">
                <p class="eyebrow">"macOS 14+ · Apple Silicon · MIT"</p>
                <h1>
                    "Read anything aloud, "<span class="accent">"on your Mac."</span>
                </h1>
                <p class="lede">
                    "MLXRead replaces macOS Speak Selection with a local MLX voice. Select text in any app — Safari, Notes, Xcode, a PDF — press "
                    <OptEsc/>
                    ". With a warm Soprano model, audio begins in about a second. Selected text is never uploaded or logged."
                </p>
                <div class="hero__actions">
                    <A href="/get-started" attr:class="btn btn--primary">"Get started"</A>
                    <a class="btn btn--ghost" href="#how">"See how it works"</a>
                </div>
                <p class="hero__foot mono muted">
                    "macOS 14+ · Apple Silicon · signed & notarized · ~"
                    <span class="dl-size">"26 MB"</span>
                </p>
            </div>

            <div class="demo">
                <div class="demo__window" class:demo__window--live=move || selecting.get()>
                    <div class="titlebar">
                        <span class="lights"><i></i><i></i><i></i></span>
                        <span class="titlebar__label mono">"Safari — Essay"</span>
                    </div>
                    <div class="demo__body">
                        <p>
                            "The kettle clicked off. "
                            <mark class="sel" class:sel--on=move || selecting.get()>
                                "She read the last paragraph twice, then let the words settle before answering."
                            </mark>
                            " Outside, the street was already awake."
                        </p>
                    </div>
                </div>

                <div class="hud" class:hud--busy=move || is_running.get()>
                    <div class="hud__top">
                        <span class="hud__dot" class:hud__dot--on=move || is_running.get()></span>
                        <span class="hud__status mono">{move || phase.get().status()}</span>
                        <span class="hud__spacer"></span>
                        <span class="hud__speed mono muted">"1.0×"</span>
                    </div>
                    <Waveform active=is_speaking/>
                    <div class="flow">
                        {["idle", "capture", "generate", "speak"]
                            .iter()
                            .enumerate()
                            .map(|(i, label)| {
                                let active = move || phase.get().index() == i;
                                let done = move || phase.get().index() > i && phase.get() != Phase::Idle;
                                view! {
                                    <span
                                        class="flow__step mono"
                                        class:flow__step--active=active
                                        class:flow__step--done=done
                                    >
                                        {*label}
                                    </span>
                                }
                            })
                            .collect_view()}
                    </div>
                    <button class="trigger" on:click=toggle>
                        <OptEsc/>
                        <span class="trigger__label">
                            {move || if is_running.get() { "Stop" } else { "Read selection" }}
                        </span>
                    </button>
                </div>
            </div>
        </section>
    }
}

#[component]
fn HowItWorks() -> impl IntoView {
    let steps = [
        (
            "01",
            "Capture the selection",
            "MLXRead reads the frontmost app's selected text through the macOS Accessibility API. When an app doesn't expose it, a clipboard-copy fallback steps in — and restores your clipboard exactly, only if nothing else touched it.",
        ),
        (
            "02",
            "Normalize and chunk",
            "The text is cleaned and split into sentence chunks deterministically, so the reader can start speaking the first sentence while the rest is still being prepared.",
        ),
        (
            "03",
            "Synthesize locally",
            "A native MLX model — Kokoro or Soprano — turns each chunk into audio on the Apple-Silicon GPU. The model loads once and stays warm between reads.",
        ),
        (
            "04",
            "Stream, then stop on a dime",
            "Playback begins on the first chunk. Press ⌥⎋ again and generation is cancelled, the queue is cleared, and audio stops in tens of milliseconds.",
        ),
    ];

    view! {
        <section id="how" class="band">
            <header class="band__head">
                <p class="eyebrow">"How it works"</p>
                <h2>"One shortcut, four honest steps."</h2>
                <p class="band__sub">
                    "No cloud round-trip, no queue on someone else's server. The whole loop runs between your selection and your speakers."
                </p>
            </header>
            <ol class="steps">
                {steps
                    .into_iter()
                    .map(|(n, title, body)| {
                        view! {
                            <li class="step">
                                <span class="step__n mono">{n}</span>
                                <div class="step__text">
                                    <h3>{title}</h3>
                                    <p>{body}</p>
                                </div>
                            </li>
                        }
                    })
                    .collect_view()}
            </ol>
        </section>
    }
}

#[component]
fn Privacy() -> impl IntoView {
    let facts = [
        "Selected text lives in memory only while it's being read — never written to disk.",
        "Selected text is never logged. Logs record lengths and timings, never content.",
        "No analytics, no crash-reporting SDK, no accounts.",
        "Model and pronunciation assets, update checks, and support use the network. Selected text never does.",
    ];

    view! {
        <section id="privacy" class="band band--edge">
            <div class="privacy">
                <div class="privacy__copy">
                    <p class="eyebrow">"Private by construction"</p>
                    <h2>"Your words stay on your Mac."</h2>
                    <p class="band__sub">
                        "This isn't a promise bolted on afterward — it's how the app is built. Synthesis runs in-process on the local GPU, so there is nowhere for the text to go."
                    </p>
                    <ul class="ticks">
                        {facts
                            .into_iter()
                            .map(|f| view! { <li><span class="tick" aria-hidden="true"></span>{f}</li> })
                            .collect_view()}
                    </ul>
                </div>
                <figure class="boundary" aria-label="Data-flow boundary diagram">
                    <figcaption class="mono muted">"your Mac"</figcaption>
                    <div class="boundary__flow">
                        <span class="node mono">"selection"</span>
                        <span class="arrow">"→"</span>
                        <span class="node mono">"MLX model"</span>
                        <span class="arrow">"→"</span>
                        <span class="node node--out mono">"audio"</span>
                    </div>
                    <div class="boundary__net mono muted">
                        "network: assets, updates & support — never selected text"
                    </div>
                </figure>
            </div>
        </section>
    }
}

#[component]
fn Performance() -> impl IntoView {
    let metrics = [
        ("~0.9s", "warm time to first audio", "Soprano, measured"),
        ("18×", "faster than real time", "Soprano synthesis"),
        ("34–46ms", "stop latency", "second ⌥⎋ to silence"),
        ("2", "local voices", "Kokoro 82M · Soprano 80M"),
    ];

    view! {
        <section id="speed" class="band">
            <header class="band__head">
                <p class="eyebrow">"Fast, and real speech"</p>
                <h2>"Latency you can live with."</h2>
                <p class="band__sub">
                    "Kokoro brings 54 natural voices across nine languages; Soprano is a lean, English, low-latency reader. Both stay warm so later reads do not reload the model."
                </p>
            </header>
            <div class="metrics">
                {metrics
                    .into_iter()
                    .map(|(value, label, note)| {
                        view! {
                            <div class="metric">
                                <span class="metric__value">{value}</span>
                                <span class="metric__label">{label}</span>
                                <span class="metric__note mono muted">{note}</span>
                            </div>
                        }
                    })
                    .collect_view()}
            </div>
            <p class="metrics__foot mono muted">
                "Measured on Apple Silicon, 488-character passage, warm model. Numbers are the app's own, not estimates."
            </p>
        </section>
    }
}

#[component]
fn Reach() -> impl IntoView {
    let apps = [
        "Safari",
        "Notes",
        "TextEdit",
        "Xcode",
        "Mail",
        "PDFs with a text layer",
    ];

    view! {
        <section class="band band--edge">
            <header class="band__head">
                <p class="eyebrow">"Everywhere you read"</p>
                <h2>"If you can select it, you can hear it."</h2>
                <p class="band__sub">
                    "Accessibility first, clipboard fallback second. Standard AppKit and SwiftUI text controls, WebKit content, and text-layer PDFs are all fair game."
                </p>
            </header>
            <ul class="chips">
                {apps
                    .into_iter()
                    .map(|a| view! { <li class="chip mono">{a}</li> })
                    .collect_view()}
            </ul>
        </section>
    }
}

#[component]
fn OpenSource() -> impl IntoView {
    view! {
            <section id="install" class="band">
                <header class="band__head">
                    <p class="eyebrow">"Open, and yours"</p>
                    <h2>"Download it, or build it yourself."</h2>
                    <p class="band__sub">
                        "MLXRead is MIT-licensed and signed with a Developer ID. Updates ship through Sparkle with EdDSA-signed appcasts — every update is verified before it installs."
                    </p>
                </header>

                <div class="install">
                    <div class="install__get">
                        <A href="/get-started" attr:class="btn btn--primary">"Install MLXRead"</A>
                        <p class="mono muted install__hint">
                            "Unzip, drag to Applications, and open it. "
                            <b>"Signed and notarized by Apple"</b>
                            " — no Gatekeeper warning."
                        </p>
                        <div class="terminal">
                            <div class="titlebar">
                                <span class="lights"><i></i><i></i><i></i></span>
                                <span class="titlebar__label mono">"zsh — build from source"</span>
                            </div>
                            <pre class="terminal__body mono">
    <span class="cmt">"# macOS 14+, Apple Silicon, Xcode"</span>"\n"
    <span class="pr">"$ "</span>"git clone https://github.com/rogu3bear/mlxread\n"
    <span class="pr">"$ "</span>"brew install xcodegen && xcodegen generate\n"
    <span class="pr">"$ "</span>"script/build_and_run.sh --verify\n"
    <span class="ok">"==> Verify OK — MLXRead is running"</span>
                            </pre>
                        </div>
                    </div>
                    <div class="install__notes">
                        <div class="note">
                            <h3>"First launch"</h3>
                            <p>
                                "Grant Accessibility access when asked — it powers both the "<OptEsc/>" tap and reading the selection. MLXRead never changes your system settings for you."
                            </p>
                        </div>
                        <div class="note">
                            <h3>"System voice"</h3>
                            <p>
                                "MLXRead also installs a Speech Synthesis Provider — its voice appears in "
                                <code class="mono">"AVSpeechSynthesisVoice.speechVoices()"</code>
                                " and to the "<code class="mono">"say"</code>" command."
                            </p>
                        </div>
                        <div class="note">
                            <h3>"Auto-updates"</h3>
                            <p>
                                "Once installed, MLXRead keeps itself current through Sparkle — signed updates pulled from the same GitHub releases, verified before install."
                            </p>
                        </div>
                        <a class="btn btn--ghost" href=REPO_URL rel="noopener" target="_blank">
                            "View source ↗"
                        </a>
                    </div>
                </div>
            </section>
        }
}

#[component]
fn ClosingCta() -> impl IntoView {
    view! {
        <section class="cta">
            <h2>"Stop reading with your eyes when you don't have to."</h2>
            <p class="band__sub">"Select. "<OptEsc/>". Listen. Entirely on your Mac."</p>
            <A href="/get-started" attr:class="btn btn--primary">"Hear your first selection"</A>
        </section>
    }
}
