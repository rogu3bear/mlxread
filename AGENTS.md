# mlxread — Agent Notes

<!-- forest-alignment:start -->
## Operating scope

Follow the active harness and enclosing workspace instructions. This repository
owns its product, implementation, and verification. Read `ANCHOR.md` when
present, then the task-specific owner below. Preserve one writer and unrelated
work. Local checks, integration, and live release require separate evidence.
<!-- forest-alignment:end -->

## Product and proof owners

Read `README.md` for the app, `CONTRIBUTING.md` for local setup,
`docs/privacy.md` for data-flow and offline claims, and `docs/updates.md` for
update/release behavior. `website/AGENTS.md` owns the public-site subtree.

MLXRead is a native macOS selection-to-speech utility. Preserve local synthesis,
clipboard restoration, truthful Accessibility permission handling, and the
boundary that selected text is never transmitted, persisted, or logged.
`project.yml` and the Xcode scripts own native builds; plain `swift build` does
not build the required Metal kernels. `script/test.sh` is the local unit-test
entrypoint; model, UI, packaging, and notarization claims require their separate
README-documented proof. Installation and publication are explicit actions.

## Cloudflare Token Doctrine

Use the active `cfctl` skill and current capability guide for authentication,
credential lifecycle, live reads, and mutations. This repository owns app
configuration and release gates. Missing capabilities or unhealthy credential
storage block the affected operation; do not bypass them with raw HTTP,
the dashboard, or direct Wrangler control-plane calls.

Keep credentials purpose-scoped and secrets out of argv, output, logs, and
commits. Builds and dry-runs prove preparation only. Retain any tighter local
restriction below.
