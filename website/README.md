# MLXRead — website

The marketing + demo site for [MLXRead](../README.md): a beautiful, fast,
single-page site that shows what MLXRead does and how it functions.

Built with **Leptos 0.8 (SSR + hydration) on Cloudflare Workers**, derived from
the [`leptos-cf`](https://github.com/) starter. The interactive ⌥⎋ demo is real
Leptos reactivity (an epoch-cancelled state machine that mirrors the app's own
generation-id guard), server-rendered on the edge and hydrated in the browser.

## What's here

- `src/app.rs` — router, SSR shell, meta, hashed-asset hydration.
- `src/components/home_page.rs` — the whole landing page + the interactive demo.
- `src/components/widgets.rs` — `Keycap`, `OptEsc`, `Waveform`.
- `src/components/app_layout.rs` — header + footer.
- `src/lib.rs` — the hardened Cloudflare Worker `fetch` handler (CSP with a
  hashed hydration script, security headers, session cookie, same-origin
  guards). Kept from the template; the D1 data layer and server functions were
  removed because the site has no backend.
- `style/main.css` — the terminal-native dark design system (amber = audio,
  green = privacy/verified, mono for keys and technical labels).

## Develop

```bash
cargo leptos watch        # http://127.0.0.1:57591 with live reload
```

## Build (edge bundle)

```bash
bash ./scripts/build-edge.sh
```

This runs `cargo leptos build --release`, hashes the JS/WASM/CSS assets,
compiles the SSR worker with `worker-build`, writes `build/_worker.js`, and
verifies the hashed-asset and worker-runtime invariants. Output:

- `target/site/` — static assets served by Workers Assets (`env.ASSETS`).
- `build/_worker.js` — the Worker entrypoint.

Requires the pinned toolchain: `cargo-leptos 0.3.5`, `worker-build 0.7.5`,
`wasm-bindgen 0.2.108`, Bun.

## Deploy

**Live:** https://mlxread-web.pages.dev (Cloudflare Pages).

The site deploys to **Cloudflare Pages** in advanced mode. Because Pages
requires a Module-syntax worker (`export default { fetch }`) and does not serve
static assets automatically, `scripts/build-pages.sh` wraps the worker-build
output in a thin module worker (`scripts/pages-worker-entry.js`) that serves
assets via `env.ASSETS` and delegates everything else to the Leptos SSR worker.

```bash
bash ./scripts/build-pages.sh                 # -> dist-pages/ (assets + _worker.js/)
bunx wrangler@4.83.0 pages dev dist-pages      # local preview on the Pages runtime
bunx wrangler@4.83.0 pages deploy dist-pages \
  --project-name mlxread-web --branch main     # deploy (main = production)
```

Project created once with:
`wrangler pages project create mlxread-web --production-branch main --compatibility-date 2026-04-22`
(the compatibility date must support `WorkerEntrypoint`).

`wrangler.toml` (the `main` + `[assets]` Workers config) is kept for
`cargo leptos` / `build-edge.sh` and local `wrangler dev`; the Pages path uses
`dist-pages/` instead. There is no D1 / data layer.

## Design intent

Terminal-native, system-utility precision. The waveform is the product's real
output motif (it animates only while "speaking"), the keyboard chord ⌥⎋ is a
first-class UI element, and the copy is grounded in the app's actual behavior
and measured numbers — no invented claims.
