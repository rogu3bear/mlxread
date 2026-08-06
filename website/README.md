# MLXRead website

The public product, first-read, privacy, FAQ, and support experience for
[MLXRead](../README.md). It is a Leptos 0.8 application with edge SSR,
progressive router navigation, and one hydrated read-lifecycle interaction.
Synchronous product routes use complete-document SSR so the edge does not emit
out-of-order suspended fragments. Leptos's deterministic empty resource-state
scripts and the hydration module are authorized by exact CSP hashes.

## Product routes

- `/` — product promise, interactive read lifecycle, privacy, performance.
- `/get-started` — canonical download-to-first-read journey.
- `/faq` and `/support` — recovery, troubleshooting, and contact.
- `/privacy` and `/terms` — product and website policies.

Route changes use Leptos Router. Content and the support form remain usable
without JavaScript. Unknown routes return an HTTP 404 rather than only drawing
a not-found view.

## Runtime

- `src/app.rs` owns the SSR shell, router, metadata context, and route list.
- `src/components/app_layout.rs` owns shared route-aware navigation.
- `src/components/get_started_page.rs` owns the first-read journey.
- `src/lib.rs` owns the Cloudflare fetch handler, route response headers,
  security policy, same-origin API guards, and payload limits.
- `scripts/write-worker-shim.mjs` generates the Workers entrypoint that serves
  hashed assets, proxies the same-origin contact form, and delegates documents
  to Leptos SSR.
- `scripts/pages-worker-entry.js` provides the equivalent wrapper for the
  Cloudflare Pages advanced-mode package.

There is no database, account state, realtime transport, or analytics layer.

## Develop

Install or verify the pinned toolchain, then run Leptos locally:

```bash
bash ./scripts/bootstrap.sh
cargo leptos watch
```

The Leptos development server listens at `http://127.0.0.1:57591`.

## Verify

```bash
bash ./scripts/verify.sh
```

The release gate runs formatting, SSR compilation, the complete browser and
edge WASM builds through the Cargo.lock-resolved `wasm-bindgen` CLI,
asset/runtime contract checks, and a Wrangler deployment dry-run.

## Build and preview

Workers Assets bundle:

```bash
bash ./scripts/build-edge.sh
bunx wrangler@4.83.0 dev --local --ip 127.0.0.1 --port 57581
```

Pages advanced-mode package:

```bash
bash ./scripts/build-pages.sh
bunx wrangler@4.83.0 pages dev dist-pages
```

The build hashes browser JS, WASM, and CSS. Hashed assets are immutable; SSR
documents require revalidation; API rejection responses are private and
`no-store`. The Worker compatibility date is pinned to `2026-04-22`, the latest
date supported by the repository-pinned Wrangler 4.83.0 runtime.

## Deploy

The compatibility production endpoint is
[`mlxread-web.pages.dev`](https://mlxread-web.pages.dev). The canonical product
domain is `https://mlxread.com`; it is not considered released until DNS, TLS,
routes, status codes, content, and response headers pass live readback.

Pages deployment:

```bash
bash ./scripts/build-pages.sh
bunx wrangler@4.83.0 pages deploy dist-pages \
  --project-name mlxread-web --branch main
```

Workers deployment uses `wrangler.toml` and the `build/_worker.js` entrypoint.
Cloudflare mutations must use the repository's purpose-scoped child token and
the operator's governed deployment lane; the account minter never enters this
repository or CI.

## Design intent

The surface uses the product's waveform, keyboard chord, dark graphite field,
and warm amber action color. Copy is grounded in observed application behavior
and measured numbers. The first-read route favors explicit prerequisites and
recovery over simulated macOS UI or invented claims.
