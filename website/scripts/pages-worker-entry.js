// Cloudflare Pages advanced-mode entry (Module syntax).
//
// Pages requires `export default { fetch }` — not the WorkerEntrypoint class
// that worker-build emits — and does NOT serve static assets automatically:
// the Function must call env.ASSETS.fetch() itself. This thin wrapper does
// both: it serves the built static assets for known asset paths and drives
// the Leptos SSR worker (a WorkerEntrypoint subclass) for everything else.
//
// Generated into dist-pages/_worker.js/index.js by scripts/build-pages.sh
// alongside leptos_core.js (the worker-build output) and index_bg.wasm.
import LeptosWorker from "./leptos_core.js";

const ASSET_PATHS = new Set([
  "/favicon.svg",
  "/app-icon.svg",
  "/app-icon-192.png",
  "/app-icon-512.png",
  "/apple-touch-icon.png",
  "/site.webmanifest",
  "/asset-manifest.json",
]);
const ASSET_PREFIXES = ["/pkg/"];

function isStaticAsset(pathname) {
  return ASSET_PATHS.has(pathname) || ASSET_PREFIXES.some((p) => pathname.startsWith(p));
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (isStaticAsset(url.pathname)) {
      return env.ASSETS.fetch(request);
    }
    // SSR: construct the worker-build WorkerEntrypoint and delegate.
    const worker = new LeptosWorker(ctx, env);
    return worker.fetch(request);
  },
};
