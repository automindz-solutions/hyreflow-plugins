# Changelog

All notable changes to the Hyreflow plugin are documented here. Versions track
the plugin, kept in lockstep across the marketplace manifests and the plugin's
own `plugin.json` files.

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
