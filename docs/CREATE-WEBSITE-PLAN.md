# Create Website Plan — MLXRead

This plan records the current website creation journey without pretending an implemented product is a blank-slate project.

## Intake

- Product: private, local selected-text speech for Apple Silicon Macs.
- Audience: Mac readers who prioritize privacy, natural speech, and a low-friction shortcut.
- Primary action: get started and download the signed release.
- Shape: real multipage Leptos Router surface.
- Stack: Leptos 0.8, Cargo Leptos, Rust edge SSR, Cloudflare Pages advanced mode.
- Proof assets: source behavior, signed/notarized distribution, update policy, measured model-specific performance. No testimonials or analytics are asserted.
- Craft: high; the waveform, graphite field, amber action, and keyboard chord belong to the product.

## Phase status

1. Purpose and audience — complete; grounded in product source, low-confidence persona.
2. Information architecture — complete; `/`, `/get-started`, `/faq`, `/support`, `/privacy`, `/terms`, and 404.
3. Content — complete for launch after the current truth corrections.
4. Visual direction — complete; product-specific and rendered at desktop/mobile sizes.
5. Component and route architecture — complete; Leptos Router and shared layout.
6. Build and runtime — complete locally; Cargo Leptos and Pages advanced-mode package.
7. Accessibility and responsive implementation — locally reviewed; final canonical-host review pending.
8. Measurement — awaiting evidence; no analytics are silently introduced.
9. Nurture/secondary conversion — intentionally skipped; one direct product journey is appropriate.
10. Production validation — pending cfctl deploy, domain attachment, and live readback.

Canonical product and launch decisions live in `docs/website-delivery.md`; this file is only the create-journey checkpoint.
