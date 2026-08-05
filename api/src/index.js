// MLXRead delivery worker.
//
// Two jobs, both ending in an email to the maintainer (never exposed to users):
//   POST /contact  -- website contact form (small JSON), reply-to the sender.
//   POST /report   -- in-app "Report a problem": multipart {email, description,
//                     bundle=<debug .zip>}. The bundle is stored in R2 and the
//                     notification email carries an unguessable download link
//                     (and the bundle attached inline when small enough).
//   GET  /d/:id     -- maintainer-only download of a stored bundle (the id is a
//                     128-bit random token; objects are never listed publicly).
//   GET  /health    -- liveness.
//
// Delivery is Cloudflare Email Routing via the restricted `send_email` binding,
// which can only ever reach the configured maintainer address.

import { EmailMessage } from "cloudflare:email";
import { createMimeMessage } from "mimetext";

const MAX_CONTACT_MSG = 6000; // chars
const MAX_NAME = 200;
const MAX_DESC = 6000; // chars
const MAX_BUNDLE = 5 * 1024 * 1024; // 5 MiB (Email + R2 ceiling)
const ATTACH_LIMIT = 3 * 1024 * 1024; // attach inline below this, else link-only
const RL_LIMIT = 6; // requests per window per IP per route
const RL_WINDOW = 3600; // seconds

const TOPICS = new Set(["general", "bug", "feature", "privacy", "other"]);

function corsHeaders(origin, allowed) {
  const h = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-MLXRead-Token",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
  if (origin && origin === allowed) h["Access-Control-Allow-Origin"] = origin;
  return h;
}

function json(obj, status = 200, extra = {}) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...extra },
  });
}

function isEmail(e) {
  return (
    typeof e === "string" &&
    e.length <= 254 &&
    /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)
  );
}

function clientIp(request) {
  return (
    request.headers.get("CF-Connecting-IP") ||
    request.headers.get("X-Forwarded-For") ||
    "unknown"
  );
}

// Best-effort throttle keyed on some caller identity. KV increments aren't
// atomic, but that's fine for deterring abuse; the restricted send binding is
// the real backstop. Contact submissions are proxied through the site worker
// (so they share one IP) — those key on the submitter email instead.
async function rateLimited(env, keyId, route) {
  if (!env.RL || !keyId) return false;
  const key = `rl:${route}:${keyId}`;
  const current = parseInt((await env.RL.get(key)) || "0", 10);
  if (current >= RL_LIMIT) return true;
  await env.RL.put(key, String(current + 1), { expirationTtl: RL_WINDOW });
  return false;
}

function randomId() {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function bufToBase64(buf) {
  const bytes = new Uint8Array(buf);
  let bin = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(bin);
}

async function sendMail(env, { subject, replyTo, text, attachment }) {
  const msg = createMimeMessage();
  msg.setSender({ name: "MLXRead", addr: env.FROM_EMAIL });
  msg.setRecipient(env.MAINTAINER_EMAIL);
  msg.setSubject(subject);
  msg.addMessage({ contentType: "text/plain", data: text });
  if (attachment) {
    msg.addAttachment({
      filename: attachment.filename,
      contentType: attachment.contentType,
      data: attachment.base64,
    });
  }
  // mimetext (3.0.x) rejects setHeader("Reply-To", ...) outright, so inject the
  // header into the raw MIME so the maintainer can reply straight to the sender.
  let raw = msg.asRaw();
  if (replyTo && isEmail(replyTo)) {
    raw = `Reply-To: <${replyTo}>\r\n${raw}`;
  }
  const em = new EmailMessage(env.FROM_EMAIL, env.MAINTAINER_EMAIL, raw);
  await env.EMAIL.send(em);
}

async function handleContact(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ ok: false, error: "bad_json" }, 400);
  }
  // Honeypot: real users never fill this hidden field. Drop before consuming
  // any rate-limit budget so bots can't exhaust a real user's quota.
  if (body && typeof body.company === "string" && body.company.trim() !== "") {
    return json({ ok: true }); // silently drop
  }
  const name = String(body?.name ?? "").trim().slice(0, MAX_NAME);
  const email = String(body?.email ?? "").trim();
  const topicRaw = String(body?.topic ?? "general").trim().toLowerCase();
  const topic = TOPICS.has(topicRaw) ? topicRaw : "other";
  const message = String(body?.message ?? "").trim();

  if (!isEmail(email)) return json({ ok: false, error: "bad_email" }, 400);
  if (message.length < 1 || message.length > MAX_CONTACT_MSG) {
    return json({ ok: false, error: "bad_message" }, 400);
  }
  // Proxied through the site worker, so key the limit on the submitter email.
  if (await rateLimited(env, email.toLowerCase(), "contact")) {
    return json({ ok: false, error: "rate_limited" }, 429);
  }

  const text = [
    `New MLXRead contact-form message`,
    ``,
    `From:    ${name || "(no name)"} <${email}>`,
    `Topic:   ${topic}`,
    `IP:      ${clientIp(request)}`,
    `Origin:  ${request.headers.get("Origin") || "-"}`,
    ``,
    `Message:`,
    message,
  ].join("\n");

  await sendMail(env, {
    subject: `MLXRead contact (${topic}) — ${name || email}`,
    replyTo: email,
    text,
  });
  return json({ ok: true });
}

async function handleReport(request, env) {
  if (env.APP_TOKEN) {
    const tok = request.headers.get("X-MLXRead-Token");
    if (tok !== env.APP_TOKEN) return json({ ok: false, error: "unauthorized" }, 401);
  }
  if (await rateLimited(env, clientIp(request), "report")) {
    return json({ ok: false, error: "rate_limited" }, 429);
  }

  let form;
  try {
    form = await request.formData();
  } catch {
    return json({ ok: false, error: "bad_form" }, 400);
  }

  const email = String(form.get("email") ?? "").trim();
  const description = String(form.get("description") ?? "").trim().slice(0, MAX_DESC);
  const appVersion = String(form.get("app_version") ?? "").trim().slice(0, 40);
  const osVersion = String(form.get("os_version") ?? "").trim().slice(0, 60);
  const file = form.get("bundle");

  if (email && !isEmail(email)) return json({ ok: false, error: "bad_email" }, 400);
  if (!file || typeof file === "string") {
    return json({ ok: false, error: "missing_bundle" }, 400);
  }
  const buf = await file.arrayBuffer();
  if (buf.byteLength === 0 || buf.byteLength > MAX_BUNDLE) {
    return json({ ok: false, error: "bad_bundle_size" }, 413);
  }

  const id = randomId();
  const key = `reports/${id}.zip`;
  await env.REPORTS.put(key, buf, {
    httpMetadata: { contentType: "application/zip" },
    customMetadata: {
      email: email || "",
      app_version: appVersion,
      os_version: osVersion,
      ip: clientIp(request),
    },
  });

  const origin = new URL(request.url).origin;
  const link = `${origin}/d/${id}`;
  const sizeKb = (buf.byteLength / 1024).toFixed(0);

  const text = [
    `New MLXRead in-app problem report`,
    ``,
    `Reporter:    ${email || "(not provided)"}`,
    `App version: ${appVersion || "-"}`,
    `macOS:       ${osVersion || "-"}`,
    `Bundle:      ${sizeKb} KB  (download: ${link})`,
    `IP:          ${clientIp(request)}`,
    ``,
    `Description:`,
    description || "(none)",
  ].join("\n");

  const attachment =
    buf.byteLength <= ATTACH_LIMIT
      ? {
          filename: "mlxread-debug.zip",
          contentType: "application/zip",
          base64: bufToBase64(buf),
        }
      : null;

  await sendMail(env, {
    subject: `MLXRead report — ${email || "anonymous"}`,
    replyTo: email,
    text,
    attachment,
  });

  return json({ ok: true, id });
}

async function handleDownload(id, env) {
  if (!/^[a-f0-9]{24,}$/.test(id)) return new Response("Not found", { status: 404 });
  const obj = await env.REPORTS.get(`reports/${id}.zip`);
  if (!obj) return new Response("Not found", { status: 404 });
  const headers = new Headers();
  headers.set("Content-Type", "application/zip");
  headers.set("Content-Disposition", `attachment; filename="mlxread-debug-${id.slice(0, 8)}.zip"`);
  headers.set("Cache-Control", "private, no-store");
  return new Response(obj.body, { headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin");
    const cors = corsHeaders(origin, env.ALLOWED_ORIGIN);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    try {
      if (url.pathname === "/health") {
        return json({ ok: true, service: "mlxread-api" });
      }
      if (url.pathname === "/contact" && request.method === "POST") {
        const res = await handleContact(request, env);
        for (const [k, v] of Object.entries(cors)) res.headers.set(k, v);
        return res;
      }
      if (url.pathname === "/report" && request.method === "POST") {
        const res = await handleReport(request, env);
        for (const [k, v] of Object.entries(cors)) res.headers.set(k, v);
        return res;
      }
      if (url.pathname.startsWith("/d/") && request.method === "GET") {
        return handleDownload(url.pathname.slice(3), env);
      }
      return json({ ok: false, error: "not_found" }, 404);
    } catch (err) {
      console.error("mlxread-api error:", err && err.stack ? err.stack : String(err));
      return json({ ok: false, error: "internal" }, 500, cors);
    }
  },
};
