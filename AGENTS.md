> BYPASSED 2026-10-19 (James): use Cloudflare MCP directly; cfctl repair later. See doctrine/standing-cfctl-bypass-2026-10-19.md.

# mlxread — Agent Notes

<!-- forest-alignment:start -->
## Operating scope

Follow the active harness and enclosing workspace instructions. This repository
owns its product, implementation, and verification. Read `ANCHOR.md` when
present, then the task-specific owner below. Preserve one writer and unrelated
work. Local checks, integration, and live release require separate evidence.
<!-- forest-alignment:end -->

## Product and proof owners

Read only the owners relevant to the task:

| Task | Existing owner |
| --- | --- |
| App purpose, setup, use, and troubleshooting | [README.md](README.md) |
| Native product and design decisions | [docs/PRODUCT.md](docs/PRODUCT.md), [docs/DESIGN.md](docs/DESIGN.md) |
| Native structure, state, and concurrency | [docs/architecture.md](docs/architecture.md) |
| Dependency, model, cache, and build rationale | [docs/technical-decisions.md](docs/technical-decisions.md) |
| Local development and verification | [CONTRIBUTING.md](CONTRIBUTING.md); dated results in [docs/testing.md](docs/testing.md) |
| Data flow, offline behavior, and security | [docs/privacy.md](docs/privacy.md), [SECURITY.md](SECURITY.md), [mlxread-threat-model.md](mlxread-threat-model.md) |
| Native signing, updates, and publication | [docs/updates.md](docs/updates.md) |
| Website runtime and commands | [website/README.md](website/README.md) |
| Contact and problem-report API | [api/README.md](api/README.md) |

[HORIZON.md](HORIZON.md) records the bounded website first-read design;
[docs/website-delivery.md](docs/website-delivery.md) records its delivery
decisions and receipts. These are not app-wide purpose replacements. Dated
plans, test results, and production receipts retain their original scope; they
do not establish current runtime state or resume parked work.

MLXRead is a native macOS selection-to-speech utility. Preserve local synthesis,
clipboard restoration, truthful Accessibility permission handling, and the
boundary that selected text is never transmitted, persisted, or logged.
`project.yml` and the Xcode scripts own native builds; plain `swift build` does
not build the required Metal kernels. `script/test.sh` is the local unit-test
entrypoint; model, UI, packaging, and notarization claims require their separate
README-documented proof. Installation and publication are explicit actions.

## Cloudflare Token Doctrine

The 2026-10-19 James instruction above is the current tooling override: use
Cloudflare MCP directly and defer cfctl repair. It supersedes cfctl-only tooling
directions in `api/README.md`, `website/README.md`, and
`docs/website-delivery.md`. Their target, permission, artifact, verification,
and rollback constraints still apply. The cited
`doctrine/standing-cfctl-bypass-2026-10-19.md` is absent from this checkout;
the instruction above supplies the override without depending on that file.

This repository owns app configuration and release gates. The tooling override
does not authorize deployment, credential changes, or resuming held work.
Missing required capabilities or unavailable credentials block the affected
operation; do not substitute raw HTTP, the dashboard, or direct Wrangler
control-plane calls.

Keep credentials purpose-scoped and secrets out of argv, output, logs, and
commits. Builds and dry-runs prove preparation only. Retain any tighter local
restriction below.

<!-- agent-context-stack:start -->
## Repository context

`README.md` is the human entrypoint; this file routes agent work.
`CLAUDE.md` imports this file. Follow applicable nested instructions, including
`website/AGENTS.md` when present; the tracked website README remains its shared
runtime and command owner.

For `look north`, reopen this file and follow the smallest applicable route
above. Purpose, architecture, and technical nuance already have owners here;
missing root context sidecars are not adoption defects. Preserve the website's
existing local context without making ignored files prerequisites for a clean
clone. Update the owning document and affected references when its contract
changes; keep current task status in its existing evidence or handoff.
<!-- agent-context-stack:end -->
