---
name: sourcewhale
description: "Read from and write to SourceWhale (recruiting outreach sequencer) via its public API — list campaigns/projects, add or modify candidates, add candidates into a campaign (optionally starting outreach), search candidates by email/phone/social/photo, pull dashboard statistics, manage Zapier webhooks. Use when the user mentions SourceWhale, pushing candidates into a SourceWhale campaign, syncing sourced/enriched candidates into outreach, or SourceWhale reporting. Keys: BYOK, self-serve — connect on the dashboard Integrations page (API key + user email)."
---

# SourceWhale — Integration Meta Skill

Routing layer for all SourceWhale public-API work. This file is WHAT/guardrails; the HOW
lives in `reference/endpoints.md` and the Python client `lib/sourcewhale.py`.

## 1) What this skill governs

- Routing, auth, and safety gates for SourceWhale calls.
- Canonical execution surface: the Python client `lib/sourcewhale.py` (Python-only stack).
- Per-endpoint detail lives in `reference/endpoints.md`.

## 2) Auth & config

- **Base URL:** `https://sourcewhale.app/public-api`
- **Connect (BYOK, self-serve):** dashboard **Integrations** → SourceWhale → API key (SourceWhale
  Settings → API/Integrations) + **User email**. The engine injects both into every call for the
  workspace; there is no managed Hyreflow key. Local/dev runs read env `SOURCEWHALE_API_KEY` +
  `SOURCEWHALE_USER_EMAIL` instead.
- **User email:** most endpoints take a `userEmail` query param ("the user performing the
  action"). The connected user email is the default for every call; override per-call
  (`user_email=`) when acting as another SourceWhale user.
- **Paths CONFIRMED** from the live Swagger spec (2026-06-01) — all 8 `/v1/...` endpoints, their
  query params, the `candidates/search` key set (`socialLink|photo|email|phone`), the candidate
  field list, and the zapier bodies match `lib/sourcewhale.py` exactly. Index: `reference/docs/sourcewhale/raw/endpoints.md`.
- **Auth CONFIRMED (2026-06-01):** header **`api-key`** (raw key value, no prefix) — from the Swagger
  Authorize dialog (ApiKeyAuthorizer / Name: `api-key` / In: header). Env `SOURCEWHALE_API_KEY`; never hardcode.
- **Secret handling — MANDATORY:** never hardcode the key in any file or commit. The client
  raises if `SOURCEWHALE_API_KEY` is missing.

## 3) Read behavior — before any execution

Before writing/running a call, open `reference/endpoints.md` for the exact params, body
shape, and the candidate object fields. Don't guess field names.

## ⚠️ PREREQUISITE — the campaign must already exist (NO create-campaign API)

**SourceWhale's public API has no endpoint to create a campaign.** You can only `list_campaigns`
(read) and `add_candidates` *into an existing* campaign. Therefore, before any candidate push:

1. **STOP and tell the user explicitly:** *"SourceWhale has no API to create campaigns, so you need to
   create the campaign (and its message steps) manually in the SourceWhale app first. Tell me once it
   exists."* Do **not** attempt to create it via `request()` or any other call — there is no such endpoint.
2. **Wait for the user to confirm** the campaign has been created in the UI.
3. **Then discover its id:** `list_campaigns(user_email=…)` → find the campaign by name → use its id as
   `campaign_id` in `add_candidates`. (If `list_campaigns` doesn't show it, the user created it under a
   different `userEmail` — ask which user owns it.)

Only after the campaign exists and you've resolved its id may you proceed to the approval-gated push below.
The same applies to message/sequence steps — those are authored in the UI, not via the API.

## 4) Approval gates (writes & outreach)

SourceWhale is an **outreach** tool — writes can trigger real messages to candidates.

1. **`sendImmediately: true` on `add_candidates` STARTS OUTREACH immediately.** Treat any
   call with `send_immediately=True` as a paid/irreversible action: confirm explicitly with
   the user first. Default to `send_immediately=False` (or omit) unless told otherwise.
2. **Dry-run first.** For bulk loads, add ONE candidate first and show the user the request +
   response before continuing.
3. **Get explicit go-ahead** before adding more than one candidate or before any
   `sendImmediately` run.
4. `modify_candidate` requires a valid `candidateId` (get it via `search_candidates`).

## 5) Operations covered

- **Campaigns:** `list_campaigns` (optional metrics, partner filters) — **read-only; no create-campaign API** (see Prerequisite above: the user must create the campaign in the UI first)
- **Projects:** `list_projects`
- **Candidates:** `add_candidates` (into campaign/projects, optional immediate send),
  `modify_candidate`, `search_candidates` (by socialLink | photo | email | phone)
- **Reporting:** `dashboard_statistics` (from/to, YYYY-MM-DD)
- **Webhooks:** `zapier_subscribe`, `zapier_unsubscribe`

## 6) Handoff with the GTM/enrichment layer

Canonical recruiting flow: source + enrich candidates (your sourcing/enrichment adapters) into
a CSV → map rows to the SourceWhale candidate object → `add_candidates` into a campaign. Use
`search_candidates` to dedupe by email before adding. Inspect the CSV first;
never read large CSVs into context.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute sourcewhale <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get sourcewhale <method>` returns the live contract + cost). Base: `https://sourcewhale.app/public-api`. Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `add_candidates(candidates: list[dict], campaign_id: str | None = None, project_ids: list[str] | None = None, send_immediately: bool | None = None, user_email: str | None = None) -> Any` — POST /v1/candidates/add — add candidates, optionally into a campaign/projects.
- `dashboard_statistics(date_from: str, date_to: str) -> Any` — GET /v1/statistics/dashboard — both dates required, format YYYY-MM-DD.
- `list_campaigns(user_email: str | None = None, include_metrics: bool | None = None, partner: str | None = None, partner_filters: dict | None = None) -> Any` — GET /v1/campaigns/list — returns campaigns created by userEmail (if set).
- `list_projects(user_email: str | None = None) -> Any` — GET /v1/projects/list — list projects (for the user if userEmail set).
- `modify_candidate(candidate: dict, user_email: str | None = None) -> Any` — POST /v1/candidates/modify — update a candidate. `candidate` must include candidateId.
- `search_candidates(key: str, value: str, user_email: str | None = None) -> Any` — GET /v1/candidates/search — find candidates by an identifier.
- `zapier_subscribe(url: str, subscription_type: str) -> Any` — POST /v1/zapier/subscribe — register a webhook URL for a subscription type.
- `zapier_unsubscribe(subscription_id: str) -> Any` — POST /v1/zapier/unsubscribe — remove a webhook subscription by id.

<!-- API-SURFACE:END -->
