use leptos::prelude::*;

/// A physical-looking keyboard keycap. `keys` is the label, e.g. "⌥" or "esc".
#[component]
pub fn Keycap(#[prop(into)] keys: String, #[prop(optional)] wide: bool) -> impl IntoView {
    view! {
        <kbd class="keycap" class:keycap--wide=wide>{keys}</kbd>
    }
}

/// The Option-Escape shortcut rendered as two keycaps.
#[component]
pub fn OptEsc() -> impl IntoView {
    view! {
        <span class="chord">
            <Keycap keys="⌥"/>
            <Keycap keys="esc" wide=true/>
        </span>
    }
}

/// An audio-spectrum waveform. Animates (pulsing bars) when `active` is true,
/// otherwise rests as a flat, quiet baseline. This is the product's real
/// output motif — bars represent speech playback, not decoration.
#[component]
pub fn Waveform(
    #[prop(into)] active: Signal<bool>,
    #[prop(optional)] bars: usize,
) -> impl IntoView {
    let count = if bars == 0 { 28 } else { bars };
    // Deterministic pseudo-heights so SSR and hydration agree exactly.
    let heights: Vec<f32> = (0..count)
        .map(|i| {
            let t = i as f32;
            0.30 + 0.70 * ((t * 1.7).sin() * 0.5 + 0.5) * ((t * 0.6).cos() * 0.5 + 0.5)
        })
        .collect();

    view! {
        <div class="waveform" class:waveform--active=move || active.get() aria-hidden="true">
            {heights
                .into_iter()
                .enumerate()
                .map(|(i, h)| {
                    let style = format!(
                        "--h: {:.3}; --i: {}; animation-delay: {}ms",
                        h,
                        i,
                        (i * 45) % 900
                    );
                    view! { <span class="waveform__bar" style=style></span> }
                })
                .collect_view()}
        </div>
    }
}
