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

// Delivery worker (Cloudflare Email Routing send binding + R2). The contact
// form posts same-origin to /api/contact (keeps CSP form-action 'self'); we
// forward it here server-side so the browser never talks cross-origin.
const API_BASE = "https://mlxread-api.sp5qybrsvz.workers.dev";

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

// Read the contact form (native urlencoded POST, or JSON), forward it to the
// delivery worker, and 303 back to /support with the outcome so it renders
// server-side (works with JavaScript disabled).
async function handleContact(request) {
  const back = (status) =>
    Response.redirect(new URL(`/support?status=${status}#contact`, request.url), 303);

  let fields = {};
  try {
    const ct = request.headers.get("content-type") || "";
    if (ct.includes("application/json")) {
      fields = await request.json();
    } else {
      const form = await request.formData();
      for (const [k, v] of form.entries()) fields[k] = typeof v === "string" ? v : "";
    }
  } catch {
    return back("error");
  }

  try {
    const resp = await fetch(`${API_BASE}/contact`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: fields.name || "",
        email: fields.email || "",
        topic: fields.topic || "general",
        message: fields.message || "",
        company: fields.company || "",
      }),
    });
    const data = await resp.json().catch(() => ({}));
    return back(resp.ok && data && data.ok === true ? "sent" : "error");
  } catch {
    return back("error");
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === "/api/contact" && request.method === "POST") {
      return handleContact(request);
    }
    if (isStaticAsset(url.pathname)) {
      return env.ASSETS.fetch(request);
    }
    // SSR: construct the worker-build WorkerEntrypoint and delegate.
    const worker = new LeptosWorker(ctx, env);
    return worker.fetch(request);
  },
};
