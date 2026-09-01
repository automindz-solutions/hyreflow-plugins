---
name: recruit-crm
description: "Read from and write to Recruit CRM (candidates, companies, contacts, jobs, hiring pipeline, custom fields) via its REST API. Use when the user mentions Recruit CRM, pushing leads/candidates into the ATS, syncing companies/contacts, reading open jobs, moving candidates through hiring stages, or updating Recruit CRM custom fields. Pairs with the sourcing/enrichment layer: that produces an enriched CSV, this skill loads it into Recruit CRM. Keys: BYOK — connect your own Recruit CRM account."
---

# Recruit CRM — Integration Meta Skill

> **Confidence: highest of the CRMs** — every path is taken straight from Recruit CRM's own live docs
> (20 endpoint groups; cache: `reference/docs/recruitcrm/raw/`). Base `https://api.recruitcrm.io/v1`, Bearer.

> 🔴 **PLAN-GATED:** the Open API requires a **Business or Enterprise** Recruit CRM
> plan. On lower plans **every** endpoint (list/search/**create**) returns `401 INSUFFICIENT_ACCESS — "Please
> Upgrade Your Plan…"` even with a valid key. If you hit that, it's the **account plan, not the key** — stop and
> tell the user; fall back to CSV export or another ATS (loxo/vincere/recruiterflow/bullhorn). See `references/field-notes.md`.

Routing layer for all Recruit CRM API work. This file tells you WHERE to go and the
guardrails to respect; the HOW lives in the reference playbook, the recipes, and the
Python client. Read the matching doc BEFORE making any call.

## 1) What this skill governs

- Routing, auth, and safety gates for every Recruit CRM API call.
- Canonical execution surface: the Python client at `lib/recruit_crm.py` (Python-only stack).
- Per-endpoint detail lives in `reference/endpoints.md`; task playbooks in `recipes/*.md`.

## 2) Auth & config (confirmed from public docs)

- **Base URL:** `https://api.recruitcrm.io/v1/`
- **Auth header:** `Authorization: Bearer <API_TOKEN>`
- **Token source:** Recruit CRM → Admin Settings → API & Integrations → enable toggle → copy key.
- **Secret handling — MANDATORY:** the API token is read from the environment variable
  `RECRUITCRM_API_KEY`. NEVER hardcode the key in any file, recipe, or commit. The Python
  client raises if the env var is missing.

## 3) Read behavior — before any execution

**STOP. Before writing or running a call:**

| When the task involves...                                          | Read this first                          |
| ------------------------------------------------------------------ | ---------------------------------------- |
| Any endpoint shape, params, pagination, field names                | `reference/endpoints.md`                 |
| Pushing enriched leads (companies + contacts) from a CSV           | `recipes/push-enriched-leads.md`         |
| Rate limits, batch helpers, and stress-test sizing                 | `recruit-crm-rate-limits.md`             |
| Calling the API from Python                                        | `lib/recruit_crm.py` (docstrings)        |

If the exact payload for an operation is marked `TODO (paste schema)` in
`reference/endpoints.md`, do NOT guess it — ask the user to paste that section of
https://docs.recruitcrm.io first. (The docs site is a JS-rendered SPA and cannot be scraped.)

## 4) Approval gates (writes & bulk operations)

Recruit CRM writes are real changes to a production ATS. Before any create/update or bulk push:

1. **Dry-run first.** For bulk loads, process `--rows 0:1` (one record) and show the user
   the exact payload + response before continuing.
2. **Confirm field mapping.** Custom-field IDs and hiring-stage IDs are account-specific
   (see `reference/endpoints.md` → "Account-specific IDs"). Confirm the mapping before writing.
3. **Confirm rate-limit headroom.** For >50 records, read `recruit-crm-rate-limits.md` and size the
   batch so it does not exceed `X-RateLimit-Remaining`. Use the `create_*_batch` helpers and run
   in chunks if needed.
4. **Get explicit go-ahead** before writing more than one record.

## 5) Rate limits & bulk helpers

See [`recruit-crm-rate-limits.md`](recruit-crm-rate-limits.md) for the full contract and
[`crm-bulk-pushes.md`](crm-bulk-pushes.md) for the cross-CRM bulk guide. Summary:

- Default rate limit: **60 req/min** (≤6 licenses) or **10 req/min per license** (>6 licenses).
- Batch helpers loop single `POST` calls and pace them via `RECRUITCRM_RATE_LIMIT_RPM`:
  - `create_candidates_batch(payloads)`
  - `create_contacts_batch(payloads)`
  - `create_companies_batch(payloads)`
- For 1,000+ records, chunk the input (e.g. 50–200 per call) and use the returned `failed` list to retry.

## 6) Resource groups covered

- **Candidates** — create / search / update
- **Companies & contacts** — create / update (primary target for enriched-lead pushes)
- **Jobs** — list / `jobs/search`, assign candidates
- **Pipeline & custom fields** — hiring-stage moves, deals, read/write custom fields

## 6) Handoff from the sourcing/enrichment layer

The canonical flow: the sourcing + enrichment adapters produce an enriched CSV → this skill loads
that CSV into Recruit CRM. Inspect the CSV (row count, columns, sample values) first
before mapping columns to Recruit CRM fields. Never read large CSVs into context.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute recruit_crm <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get recruit_crm <method>` returns the live contract + cost). Base: `https://api.recruitcrm.io/v1`. Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `apply_candidate_to_job(candidate_slug: str, payload: dict) -> Any` — POST /v1/candidates/{candidate}/apply.
- `assign_candidate_to_job(candidate_slug: str, payload: dict) -> Any` — POST /v1/candidates/{candidate}/assign — assign candidate to a job (job slug in body).
- `batch(method: str, calls: list, *, stop_on_error: bool = False) -> dict` — Batched get/search/update/create: run one method over many inputs, rate-limited. Each call is a value -> method(value), or {"args": [...], "kwargs": {...}} for multi-arg methods like update_candidate(slug, payload). Destructive methods (delete) are refused. See lib/_base.run_ops.
- `create_candidate(payload: dict) -> dict` — POST /v1/candidates — create a candidate. Required: `first_name`.
- `create_candidates_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /v1/candidates (repeated, rate-limited).
- `create_companies_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /v1/companies (repeated, rate-limited). See create_candidates_batch.
- `create_company(payload: dict) -> dict` — POST /v1/companies — create a company. Required: `company_name`.
- `create_contact(payload: dict) -> dict` — POST /v1/contacts — create a contact. Required: `first_name`, `last_name`.
- `create_contacts_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /v1/contacts (repeated, rate-limited). See create_candidates_batch.
- `create_job(payload: dict) -> dict` — POST /v1/jobs — create a job. Required: name, number_of_openings, company_slug, contact_slug, job_description_text, currency_id. job_status: 0 Closed/1 Open/2 On-Hold/ 3 Cancelled (or custom id). File field job_description_file needs multipart (not handled).
- `get_candidate(slug: str) -> dict` — GET /v1/candidates/{slug} — single candidate by slug.
- `get_candidate_hiring_pipelines() -> Any` — GET /v1/hiring-pipelines — pipelines + stage IDs (needed for hiring-stage moves).
- `get_candidate_hiring_stages(slug: str) -> Any` — GET /v1/candidates/{slug}/hiring-stages — all jobs+stages for the candidate.
- `get_company(slug: str) -> dict`
- `get_contact(slug: str) -> dict`
- `get_job(slug: str) -> dict`
- `list_candidates(sort_by: str = 'updatedon', sort_order: str = 'desc', limit: int = 100) -> Iterator[dict]` — GET /v1/candidates — iterate all candidates. sort_by: createdon|updatedon.
- `list_companies(sort_by: str = 'updatedon', sort_order: str = 'desc', limit: int = 100) -> Iterator[dict]` — GET /v1/companies — iterate all companies.
- `list_contacts(sort_by: str = 'updatedon', sort_order: str = 'desc', limit: int = 100) -> Iterator[dict]` — GET /v1/contacts — iterate all contacts.
- `list_custom_fields(entity: str = '') -> Any` — GET /v1/custom-fields[/{entity}] — custom field IDs. entity e.g.
- `list_jobs(sort_by: str = 'updatedon', sort_order: str = 'desc', limit: int = 100) -> Iterator[dict]` — GET /v1/jobs — iterate all jobs.
- `search_candidates(*, custom_fields: list[dict] | None = None, **filters) -> Iterator[dict]` — GET /v1/candidates/search — query filters + optional custom_fields body.
- `search_companies(*, custom_fields: list[dict] | None = None, **filters) -> Iterator[dict]` — GET /v1/companies/search. Filters: company_name, company_slug, owner_email, owner_id, owner_name, created_from/to, updated_from/to, marked_as_off_limit, exact_search. custom_fields body: [{field_id, filter_type, filter_value}].
- `search_contacts(*, custom_fields: list[dict] | None = None, **filters) -> Iterator[dict]` — GET /v1/contacts/search — query filters + optional custom_fields body.
- `search_jobs(*, custom_fields: list[dict] | None = None, **filters) -> Iterator[dict]` — GET /v1/jobs/search — query filters + optional custom_fields body.
- `update_candidate(slug: str, payload: dict) -> dict` — POST /v1/candidates/{slug} — edit a candidate (POST, not PUT).
- `update_candidate_hiring_stage(candidate_slug: str, job_slug: str, payload: dict) -> Any` — POST /v1/candidates/{candidate}/hiring-stages/{job} — move candidate's stage in a job.
- `update_company(slug: str, payload: dict) -> dict` — POST /v1/companies/{slug} — edit (POST, not PUT). `company_name` required again.
- `update_contact(slug: str, payload: dict) -> dict` — POST /v1/contacts/{slug} — edit a contact (POST, not PUT).
- `update_job(slug: str, payload: dict) -> dict` — POST /v1/jobs/{slug} — edit a job (POST, not PUT).

<!-- API-SURFACE:END -->
