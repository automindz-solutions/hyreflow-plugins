# Changelog

All notable changes to the Hyreflow plugin are documented here. Versions track
the plugin, kept in lockstep across the marketplace manifests and the plugin's
own `plugin.json` files.

## 0.1.7 — 2026-09-01

First skills sync since 0.1.6 (2026-08-10).

**Added**
- SendKit.ai (email sequencer) and Spott.io (recruiting CRM) playbooks — both BYOK.
- `linkedin_profile` enrichment: employment history, plus LinkedIn post feeds as a
  credit-metered Hyreflow Native scrape.
- Loxo company endpoints, so target accounts are readable from Loxo.
- `tools search` points at the recipe for an intent, not just the tool.

**Fixed**
- `people_search` keeps its nested query and `titles[]` on a no-result retry, and falls
  back to the public web for a company no people-DB covers (verified on whole-name
  boundaries).
- Enrichment keeps work emails on the candidate's current employer, preserves provenance
  in CSV exports, resolves BOM'd headers, and enriches the full profile before scoring.
- Waterfall runs show progress instead of blocking silently; an empty managed result is
  flagged when the provider is out of credits.
- Skills answer in the user's language and stop mangling place names.
- IT sourcing's people-DB leg is volume-matched; hiring signals prefer native job scrapes
  over TheirStack; a Germany-scoped hiring query reaches the German job board.

**Changed**
- Pricing: one field, one cost per enrich method; 50% margin floor; Serper managed and
  priced from its purchase rate; exa priced off Exa's PAYGO rate card.
- BYOK-only for every CRM, sequencer and comms tool.
- The n8n integration is gone — workflows are native. Its setup, node reference, and
  builder agent are removed from this plugin.
- Native scrape polling drops to 10s, and enrich rows run in parallel.

## 0.1.6 — 2026-08-10

First skills sync since 0.1.5 (2026-07-30).

**Fixed**
- `people_search` no longer silently drops filters or bills for out-of-filter results.
- Prospeo reveal pricing now reflects what the customer is actually charged.
- The setup skill no longer prompts for install method, verifies the CLI install, and
  the recruit-skill fallback path is fixed.

**Changed**
- Every endpoint's price now derives from vendor cost at a 70% margin floor.
- Apify moved to BYOK-only billing.
- Agent skills are installable by any harness, Hermes first.

## 0.1.5 — 2026-07-30

First skills sync since 0.1.4 (2026-07-14), so this covers two weeks of engine changes.

**New**
- Three recipes: **Network ICP Qualification**, **Candidate-led BD campaign** (MPC shot),
  and **CRM Matching** (sourcing from an existing candidate base).
- **Hyreflow Natives** — first-party job scrapers, with a `hyreflow_native` playbook.
- Playbooks for **Atlas** (rebuilt against the real API spec), plus bulk-CRM-push and
  Recruit CRM rate-limit guidance.

**Corrected**
- Pricing figures in `references/cost-card.md` now come from a single authored source,
  so credit costs match what the engine actually bills.
- Provider method names that didn't exist: TheirStack (`search_companies`, `search_jobs`,
  `company_technographics`), FullEnrich (`start_bulk_enrichment`, `get_bulk_enrichment`,
  `start_reverse_email`, `get_reverse_email` — and it has no people-search method),
  BetterContact (one `start_enrichment`, not separate single/bulk tools).
- AI Ark `employeeSize` and text-filter shapes — the documented shape was silently ignored.
- Loxo: correct API host, and `LOXO_DOMAIN` removed (it was never read).
- Icypeas: `ICYPEAS_ACCOUNT_EMAIL` was a required env var and went undocumented.
- ZoomInfo and JobAdder are no longer described as self-serve "paste your key" BYOK —
  both use OAuth credentials that can't be connected from the dashboard today.
- Shovels is BYOK-only.
- Native job scrapes bill per unique job, not per page window.
- Removed links to a private repo that end users can't open.

## 0.1.4 — 2026-07-14

- Deepline-parity sign-in: `hyreflow auth login` prints a browser link and returns
  (no hang in agent sandboxes), `hyreflow auth wait` completes the approval, and
  `hyreflow auth status` recovers a pending sign-in. Quickstart flow simplified.

## 0.1.3 — 2026-07-14

- CLI install is now sandbox-safe: the npm step uses a no-sudo user prefix and
  quiet flags (`--prefix "$HOME/.local" --silent --no-fund --no-audit`) so it
  doesn't hit a global-install EACCES or flood an agent's tool output.

## 0.1.2 — 2026-07-14

- CLI install now prefers **`npm install -g hyreflow`** (public npm) across all
  skills, with the curl installer as a no-Node fallback.

## 0.1.1 — 2026-07-13

- Skills re-synced to the current engine (provider-playbook + reference doc
  updates: leadmagic, field notes, n8n node reference).

## 0.1.0 — 2026-07-10

Initial release. Single `hyreflow` plugin bundling the recruitment-automation
skills: `hyreflow-recruit`, `hyreflow-quickstart`, `hyreflow-workflows`,
`hyreflow-feedback`.

- Claude Code + Claude Cowork: install as a marketplace plugin.
- Codex + Cursor: manifests shipped (beta — please report issues).
- `PreToolUse` approval hook auto-approves read-only, non-spending `hyreflow`
  CLI calls; anything that spends credits or changes auth still prompts.

_Reserved for a future release: serving the Hyreflow CLI binary directly from
this repo's GitHub Releases (`bin/` shim + versioned release assets)._
