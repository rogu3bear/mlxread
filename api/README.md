# mlxread-api

The delivery worker behind MLXRead's **contact form** and **in-app problem
reports**. It turns both into an email to the maintainer — the maintainer's
address is never exposed to users or shipped in the app.

## What it does

| Route | Caller | Behavior |
|---|---|---|
| `POST /contact` | website contact form (proxied same-origin via the Pages worker) | Validates + honeypots the submission, then emails it (reply-to the sender). |
| `POST /report` | the macOS app's Settings → Report | Accepts a multipart debug `.zip` (≤ 5 MiB) + optional email/description, stores it in R2, and emails the maintainer with a download link and the bundle attached. Gated by an app token. |
| `GET /d/:id` | maintainer (link in the email) | Streams a stored debug bundle. `id` is a 128-bit random token; objects are never listed publicly. |
| `GET /health` | — | Liveness. |

Delivery is **Cloudflare Email Routing** via the `send_email` binding, which is
**restricted** (`destination_address: james@jkca.me`) so the worker can only
ever reach the maintainer — it cannot be turned into an open relay.

## Bindings (`wrangler.jsonc`)

- `EMAIL` — Email Routing send binding, restricted to the maintainer address.
- `REPORTS` — R2 bucket `mlxread-reports` for debug bundles.
- `RL` — KV namespace for best-effort rate limiting (contact keyed on email,
  report keyed on IP).
- Vars: `MAINTAINER_EMAIL`, `FROM_EMAIL` (must be on a domain onboarded to
  Email Routing — `jkca.me`), `ALLOWED_ORIGIN`, `APP_TOKEN` (ships in the app;
  a low-friction gate, not a real secret).

## Prerequisites

`james@jkca.me` must be a **verified Email Routing destination address** on the
Cloudflare account this worker runs in. `jkca.me` already routes mail through
Cloudflare Email Routing, so this is typically already true; if a send fails
with an unverified-destination error, add/verify it via the Email Routing
component surface.

## Develop / deploy

All Cloudflare work goes through **cfctl** (not raw wrangler) — it injects the
right token lane and gates mutations. From this directory:

```bash
bun install                              # mimetext + wrangler
cfctl wrangler deploy --plan             # preview; note the operation-id
cfctl wrangler deploy --ack-plan <id>    # deploy
cfctl wrangler tail                      # live logs
```

After deploying, put the worker's `*.workers.dev` URL in two places:

- `website/scripts/pages-worker-entry.js` → `API_BASE`
- `MLXRead/Support/Constants.swift` → `Constants.Report.endpoint`

then rebuild + redeploy the site and re-cut the app.

## Privacy

Debug bundles contain only app/OS/hardware versions, model + permission state,
and recent app-log lines (timings, counts, and error messages) — **never** the
user's selected or spoken text. The app assembles the bundle and shows the user
exactly what it contains before sending.
