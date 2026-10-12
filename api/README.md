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

## Develop and release

Install dependencies and use the local emulator from this directory:

```bash
bun install
bun run dev
```

The API is the separate `mlxread-api` Worker declared in `wrangler.jsonc`.
The website Pages project is a different deployment target; publishing either
one does not publish the other. API account operations, deployment and live logs
use the current `cfctl` executable on PATH. The former direct `deploy` and `tail`
package aliases are removed: neither the archived `cfctl wrangler` grammar nor a
raw Wrangler command is a release fallback.

1. Bind the intended account, explicit managed profile, exact source commit and
   `api/wrangler.jsonc`. Check `cfctl version --json`, `cfctl doctor --json` and
   `cfctl auth status <profile> --json`. Require an available credential whose
   profile account equals the intended account; global selection is insufficient.
2. Discover the current operation with
   `cfctl resolve "deploy the mlxread-api Worker" --json`, inspect the returned
   capability with `cfctl catalog show <capability-id> --json`, then load
   `cfctl guide <capability-id> --json`. Use its supported artifact preparation,
   configuration and selectors. A blocked capability stops this release.
3. Follow the guide's bounded reads with explicit `--profile <profile>` and
   `--account <account-id>` plus the required target selectors. Create the
   deployment plan through its exact `cfctl call` command. Review
   `cfctl plans show <operation-id> --json`: source/artifact identity, target,
   bindings, permissions, cost, verification and compensation must agree.
4. After approval of that exact plan, use `cfctl plans approve <operation-id>
   --yes`, `cfctl plans run <operation-id>` and `cfctl plans status <operation-id>`,
   with `--json` for machine consumption. Read back the deployed version and
   bindings through the guide, and check `/health`. Retain the previous version
   for a separately reviewed compensation plan if verification fails.

Keep credentials in cfctl's managed store; do not copy a token into this
repository for routine deployment. Discover log reads separately through
`cfctl resolve` and their guide. A health response is not email or report-delivery
proof; tests which send email require their own authorization.

If the API URL changes, reconcile `API_BASE` in
`website/scripts/pages-worker-entry.js` and `Constants.Report.endpoint` in
`MLXRead/Support/Constants.swift`. Rebuild and release those consumers through
their own gates; never infer that an API deploy updated the website or app.

## Privacy

Debug bundles contain only app/OS/hardware versions, model + permission state,
and recent app-log lines (timings, counts, and error messages) — **never** the
user's selected or spoken text. The app assembles the bundle and shows the user
exactly what it contains before sending.
