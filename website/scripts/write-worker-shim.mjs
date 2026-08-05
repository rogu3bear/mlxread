#!/usr/bin/env bun

import { existsSync } from "node:fs";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

const root = process.cwd();
const workerBundle = join(root, "build/index.js");
const shimPath = join(root, "build/_worker.js");

if (!existsSync(workerBundle)) {
  console.error(`[write-worker-shim] missing worker bundle: ${workerBundle}`);
  process.exit(1);
}

await mkdir(dirname(shimPath), { recursive: true });
await writeFile(
  shimPath,
  [
    'import LeptosWorker from "./index.js";',
    "",
    'const API_BASE = "https://mlxread-api.sp5qybrsvz.workers.dev";',
    "",
    "const STATIC_ASSET_PATHS = [",
    '  "/asset-manifest.json",',
    '  "/app-icon.svg",',
    '  "/app-icon-192.png",',
    '  "/app-icon-512.png",',
    '  "/apple-touch-icon.png",',
    '  "/favicon.svg",',
    '  "/site.webmanifest",',
    "];",
    "",
    "const STATIC_ASSET_PREFIXES = [",
    '  "/pkg/",',
    "];",
    "",
    "function shouldServeAsset(pathname) {",
    "  return STATIC_ASSET_PATHS.includes(pathname)",
    "    || STATIC_ASSET_PREFIXES.some((prefix) => pathname.startsWith(prefix));",
    "}",
    "",
    "async function handleContact(request) {",
    "  const back = (status) =>",
    "    Response.redirect(new URL(`/support?status=${status}#contact`, request.url), 303);",
    "  let fields = {};",
    "  try {",
    '    const contentType = request.headers.get("content-type") || "";',
    '    if (contentType.includes("application/json")) {',
    "      fields = await request.json();",
    "    } else {",
    "      const form = await request.formData();",
    '      for (const [key, value] of form.entries()) fields[key] = typeof value === "string" ? value : "";',
    "    }",
    "  } catch {",
    '    return back("error");',
    "  }",
    "  try {",
    "    const response = await fetch(`${API_BASE}/contact`, {",
    '      method: "POST",',
    '      headers: { "Content-Type": "application/json" },',
    "      body: JSON.stringify({",
    '        name: fields.name || "", email: fields.email || "",',
    '        topic: fields.topic || "general", message: fields.message || "",',
    '        company: fields.company || "",',
    "      }),",
    "    });",
    "    const data = await response.json().catch(() => ({}));",
    '    return back(response.ok && data && data.ok === true ? "sent" : "error");',
    "  } catch {",
    '    return back("error");',
    "  }",
    "}",
    "",
    "export default class extends LeptosWorker {",
    "  async fetch(request) {",
    "    const url = new URL(request.url);",
    "",
    '    if (url.pathname === "/api/contact" && request.method === "POST") {',
    "      return handleContact(request);",
    "    }",
    "",
    "    if (shouldServeAsset(url.pathname)) {",
    "      return this.env.ASSETS.fetch(request);",
    "    }",
    "",
    "    return super.fetch(request);",
    "  }",
    "}",
    "",
  ].join("\n"),
);

console.log("[write-worker-shim] wrote build/_worker.js");
