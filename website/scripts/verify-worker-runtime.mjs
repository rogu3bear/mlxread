#!/usr/bin/env bun

import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

const root = process.cwd();
// Wrangler 4.83.0's bundled workerd supports compatibility dates through this
// value. Keep the date pinned with the CLI so local proof matches deployment.
const expectedCompatibilityDate = process.env.EXPECTED_COMPATIBILITY_DATE ?? "2026-04-22";
const wrangler = await readFile(join(root, "wrangler.toml"), "utf8");
const shimPath = join(root, "build/_worker.js");

function requireSnippet(label, text, snippet) {
  if (!text.includes(snippet)) {
    throw new Error(`${label} is missing required snippet: ${snippet}`);
  }
}

requireSnippet("wrangler.toml", wrangler, 'main = "build/_worker.js"');
requireSnippet(
  "wrangler.toml",
  wrangler,
  `compatibility_date = "${expectedCompatibilityDate}"`,
);
requireSnippet("wrangler.toml", wrangler, "[assets]");
requireSnippet("wrangler.toml", wrangler, 'directory = "./target/site"');
requireSnippet("wrangler.toml", wrangler, 'binding = "ASSETS"');

if (!existsSync(shimPath)) {
  throw new Error(`missing generated Worker shim: ${shimPath}`);
}

const shim = await readFile(shimPath, "utf8");
requireSnippet("build/_worker.js", shim, 'import LeptosWorker from "./index.js";');
requireSnippet("build/_worker.js", shim, "export default class extends LeptosWorker");
requireSnippet("build/_worker.js", shim, 'const API_BASE = "https://mlxread-api.sp5qybrsvz.workers.dev";');
requireSnippet("build/_worker.js", shim, "async function handleContact(request)");
requireSnippet("build/_worker.js", shim, 'url.pathname === "/api/contact"');
requireSnippet("build/_worker.js", shim, '"/pkg/"');
requireSnippet("build/_worker.js", shim, '"/asset-manifest.json"');
requireSnippet("build/_worker.js", shim, '"/app-icon.svg"');
requireSnippet("build/_worker.js", shim, '"/app-icon-192.png"');
requireSnippet("build/_worker.js", shim, '"/app-icon-512.png"');
requireSnippet("build/_worker.js", shim, '"/apple-touch-icon.png"');
requireSnippet("build/_worker.js", shim, '"/site.webmanifest"');
requireSnippet("build/_worker.js", shim, "this.env.ASSETS.fetch(request)");
requireSnippet("build/_worker.js", shim, "super.fetch(request)");

if (shim.includes("WebSocketPair") || shim.includes("/realtime/socket")) {
  throw new Error("build/_worker.js still contains the removed template WebSocket lane");
}

console.log("[verify-worker-runtime] Worker shim, compatibility date, Assets binding, contact proxy, and SSR fallback are aligned");
