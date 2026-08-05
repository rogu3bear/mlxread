# HORIZON — MLXRead first-read delivery

Stage: implemented

## Frame

This horizon governs a bounded production refactor of the MLXRead website. The
outcome is to move a qualified Apple Silicon Mac user from initial interest to
a successful first local read without changing the native application or its
published release. The job is activation and trustworthy delivery, not feature
expansion. At the implementation baseline, `NORTH_STAR.md:1` described the
inherited starter rather than the MLXRead product and was excluded as product
authority. A later product-specific local version is gitignored and therefore
remains informative rather than canonical until it is deliberately reconciled.
Product truth comes from this tracked HORIZON, the root README, native source,
release assets, and existing product-specific web pages.

## Semantic Product Contract

MLXRead is a signed and notarized macOS 14+ application for Apple Silicon. It
captures selected text, synthesizes speech locally, and does not send selected
text to a service. Its primary action is pressing Option-Escape after selecting
text. The website must explain prerequisites, installation, Accessibility
permission, local model choice, shortcut conflict recovery, first use, and
support. The primary user-visible action is “Get started,” leading to the
canonical `/get-started` route.

## Excluded North Star Design Directives

The design directives that present this repository as a public Leptos starter,
advertise D1, or expose a demonstration WebSocket are explicitly excluded
design authority. Those features are not part of MLXRead’s user value. The
existing dark, warm-amber product language, waveform icon, direct privacy copy,
and measured performance claims remain in scope because they are grounded in
the application and current product surface.

## Ground Truth and Functional Inventory

Observed routes are `/`, `/privacy`, `/terms`, `/faq`, and `/support`, plus a
wildcard visual not-found page. The current home includes a hydrated shortcut
demo, product mechanics, privacy, performance, compatibility, download, and
source guidance. Support uses a native same-origin form that an edge wrapper
proxies to the delivery Worker. The site has no accounts, D1 data, session UI,
or realtime collaboration. Current internal navigation uses raw anchors, SSR
documents use `no-store`, and the not-found view does not prove HTTP 404. The
Cloudflare zone `mlxread.com` exists but is not attached to the current Pages
project.

## Preserve and Replace Boundary

Preserve the native release URL, truthful product copy, support submission,
privacy and legal content, static asset hashing, CSP, body limits, SSR, and
progressive enhancement. Replace embedded install discovery with a canonical
first-read route, raw route-to-route anchors with Leptos Router links, visual
404-only behavior with an HTTP 404, blanket document `no-store` with explicit
revalidation, and the template WebSocket lane with the actual support proxy.
The Pages endpoint remains a compatibility consumer until the domain is proven.

## Full Design Coverage

The full design coverage includes the shared header and footer, home primary
CTA, `/get-started`, FAQ recovery links, support recovery links, legal return
links, route metadata, not-found behavior, wide layout, narrow layout, focus
behavior, reduced motion, loading, empty, and error states. The site has no
data-loading view or empty collection; those states are intentionally absent.
The support success/error banners and download/recovery guidance cover the
material feedback states.

## Hierarchy Contract

The DOM and reading order are eyebrow, primary heading, value statement,
primary action, prerequisites, sequential setup, recovery, then global footer.
On narrow screens the order remains identical, with columns collapsing without
reordering. “Get started” is primary. Download is the next committed action.
FAQ and support are secondary recovery actions. External source links are
tertiary. The header must not crowd out the primary CTA on small screens.

## Creative Direction Contract

The creative direction is calm technical confidence: dark graphite surfaces,
warm amber action emphasis, restrained mono labels, plain-language privacy, and
no speculative dashboard imagery. It should feel like a native utility made by
someone who expects scrutiny. Animation may demonstrate the read lifecycle but
must not obscure setup or persist for reduced-motion users.

## Creative Production Territory

Creative Production is bounded to the existing product asset
`website/assets/app-icon.svg` and current dark/amber visual language. A separate
mood board is not required for this already-selected refactor. If the workflow
advances, the Creative Production artifact binding remains
`website/assets/app-icon.svg`; rendered product evidence is used instead of
introducing unrelated campaign art.

## Product Design Options

### Direction A — download-only compression

Keep setup embedded on home and change only the CTA. This is easiest but leaves
first-read guidance non-routable and weakens support recovery.

### Direction B — canonical first-read journey

Add `/get-started`, connect every primary CTA through Leptos Router, and make
the route a complete download-to-first-read sequence. This creates a durable
activation contract without native app work.

### Direction C — interactive onboarding simulator

Build a richer browser simulation of permission, model download, and speech.
This may educate, but it adds state and imitation that can diverge from macOS.

## Selected Direction

Direction B is the proposed selection because it maximizes activation clarity
while minimizing application and runtime risk. The Product Design artifact is
`/Users/star/.codex/visualizations/2026/08/05/019fd35a-fdab-76e2-bfe8-cd362e753e77/mlxread-get-started-wide-clean.png`.
Exact selected Product Design result:
`/Users/star/.codex/visualizations/2026/08/05/019fd35a-fdab-76e2-bfe8-cd362e753e77/mlxread-get-started-wide-clean.png`.
The matching narrow result is
`/Users/star/.codex/visualizations/2026/08/05/019fd35a-fdab-76e2-bfe8-cd362e753e77/mlxread-get-started-narrow-clean.png`.
These are rendered from the real Leptos implementation; no generated-image
proxy is treated as production truth.

## Visualize Full-Design Review

The Visualize review used the wide and narrow rendered paths recorded in
Selected Direction. Coverage included `/get-started`, shared navigation, first
viewport hierarchy, complete reading order, recovery, focus visibility,
clipping, and horizontal overflow. Both viewports had zero horizontal overflow,
the intended heading and current-route marker, and no browser page errors. The
Visualize review limit is visual and perceptual behavior; it cannot prove HTTP
status, cache policy, hydration, or Cloudflare domain state.

## Shared Design System

Shared component and token mapping remains source-owned. Existing `.btn`,
`.band`, `.eyebrow`, `.mono`, color tokens, radii, focus styles, `AppLayout`,
`OptEsc`, and route metadata patterns are reused. New setup-specific classes
may compose those shared tokens but must not establish a parallel theme.

The de-template peer audit maps actions to `.btn`, section rhythm to `.band`,
technical labels to `.eyebrow`/`.mono`, and window-like surfaces to the existing
framed panel/titlebar rules. Steps and metrics share border tokens but retain
separate structures because their semantics, density, and responsive columns
differ. No generic card component or wider hydration boundary is admitted.

## Leptos Delivery Map

`App` owns the Router, route list, metadata context, and not-found response.
`AppLayout` owns route-aware shared navigation. `GetStartedPage` owns semantic
setup content. The home demo remains the only hydration island-like interactive
boundary; the rest is SSR content with progressive navigation. The edge fetch
function owns response status, CSP, body limits, and document cache policy.
The generated Worker shim owns assets, the contact proxy, and SSR delegation.

## Idea Server

The conventional dev-only route would be `/__ideas/mlxread-first-read`. It is
not enabled because the direction was supplied by the operator and this is a
bounded refactor of a live product, not an unresolved council exploration. No
production route or artifact depends on an Idea Server. If design direction
becomes disputed, that dev-only route is the reversible place to compare ideas.

## Responsive and Inclusive Behavior

Wide layouts may use three prerequisite columns and a split recovery section.
Narrow layouts collapse to one column without changing DOM order. Router links
must retain visible keyboard focus, `aria-current`, and semantic anchor
behavior. On narrow screens, a native `details` disclosure keeps every primary
route discoverable without JavaScript while preserving the compact header. The
skip link targets the shared main-content boundary. Reduced motion disables
entrance and demo motion. Text must remain selectable, zoomable, and usable
without JavaScript.

## Comparison and Proof Plan

Compare the selected route in real Leptos SSR against the selected Direction B
contract, not against an Idea Server mock. Prove formatting, Rust tests, SSR
compilation, edge build, generated Worker checks, and Wrangler dry-run on one
tree. Run the Pages package locally and inspect `/`, `/get-started`, `/faq`,
`/support`, and an unknown route; the unknown route must be HTTP 404. Browser
review covers wide and narrow rendering, keyboard focus, and overflow. Deploy,
domain attachment, and live readback remain separate proof gates.

## Non-goals and Reversibility

There is no native feature work, release recut, analytics, account system, D1,
Durable Object, realtime transport, or new telemetry. `/get-started` can be
removed without data migration. Router-aware links degrade to standard anchors.
The Pages URL remains available during domain cutover. No custom-domain claim
is complete until DNS, TLS, route content, HTTP status, and headers are read
back from `https://mlxread.com`.

## Decision Log

- Formal five-day Design Sprint readiness is “Wait” because a full team,
  Decider calendar, and five-user recruiting lane are not established.
- Foundation Sprint is not activated because product direction is already
  sufficiently resolved for this delivery slice.
- ICE and MoSCoW rank runtime/router correctness, canonical first-read flow,
  and domain release ahead of copy polish or native feature expansion.
- Direction B is implemented with source, runtime, and rendered evidence.
- De-template recovery retained the selected product direction, removed visible
  framework/hosting attribution, restored narrow route discovery, normalized
  focus-visible treatment, and rejected an evidence-free generic card layer.
- Recovery captures are bound to SHA-256
  `b9dde4be789609008aa5c43384afb57c130deb88532282bbe7d0f509a6d3d1ec`
  (wide home) and
  `fe8d25dfc33ba9906cbd4b0c0e2ce1d96cd8dc7e39b495d4afc6742339650cad`
  (narrow home). Their stitched repetition is not treated as runtime evidence;
  DOM counts and route checks are the adjudicating proof.
- Post-refactor viewport captures are SHA-256
  `0a70fb4fee870ae7cab88e1def56f794bd7b8185fcf887b1eb395d41337e9d5d`
  (wide home) and
  `48134a867f3bc4c8dddfd9cd7eac0c690eb3907327d164cb178d6a2c416789b3`
  (390 px home with the navigation disclosure open). Browser evidence records
  one hero at 320 px, no horizontal overflow, all five navigation targets,
  visible summary focus, and no page warnings or errors.
