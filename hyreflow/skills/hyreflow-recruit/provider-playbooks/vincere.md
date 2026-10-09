---
name: vincere
description: "Read/write Vincere (recruiting ATS/CRM) via its v2 API — search/get/create/update candidates, search jobs/companies/contacts. Use when the user mentions Vincere, pushing candidates into the ATS, or reading jobs/companies. Connect it from Integrations with the Client ID and API key Vincere issued for your account."
---

# Vincere — Integration Meta Skill

HOW in `lib/vincere.py`.

## Auth & config (two headers)
- **Base URL:** `https://{tenant}.vincere.io/api/v2` — the tenant is the workspace's own Vincere subdomain.
- **Connect:** the workspace connects Vincere from Integrations: Vincere tenant, Client ID and API key, then sign in to Vincere. Vincere Support issues the Client ID and API key per Vincere account, and must register Hyreflow's callback URL (shown on the connect form) first. No client secret.
- **Auth:** BOTH `x-api-key` AND `id-token` (**1 h TTL**). Hyreflow refreshes the id-token automatically and retries once on a 401, so never handle tokens yourself.
- **403** means Vincere refused access. Most often the API key doesn't match the Client ID Vincere issued for the account; otherwise check the connecting user's Vincere permissions. Don't retry.
- **Limits:** Vincere allows 10 requests/second and 50,000/day per API key (429 beyond that).

## Operations (paths CONFIRMED 2026-06-01; full spec signup-gated)
Candidates: `search_candidates`, `get_candidate`, `create_candidate`, `update_candidate`. Reads: `search_jobs`, `get_job`, `search_companies`, `search_contacts`. Index: `reference/docs/vincere/raw/endpoints.md`.
- **Jobs are `job` (NOT `position`)** in v2 — confirmed. Search paths carry a **trailing slash** (`/candidate/search/`).
- **Search paths:** per the spec, `fl` (returned fields) and `sort` are **matrix params on the path** (`/candidate/search/fl=id,name;sort=created_date desc?q=...`), while `q`, `fq`, `start` and `limit` are query params. The `search_*` methods build that path from their `fl` / `sort` arguments, so pass them as arguments, e.g. `{"q": "skill:python#", "fl": "id,name,primary_email,current_job_title", "sort": "created_date desc", "limit": 50}`.

## Search queries (`q`)
Vincere search runs on Solr behind **Vincere's own query parser**. It's Lucene-like but NOT plain Lucene. Source: the Search section and per-endpoint field lists of the API spec, snapshot in `reference/docs/vincere/raw/search.md`.

**Shape: every clause is `field:terms#`.** The trailing `#` is **mandatory**, because it marks where a clause ends. A clause without `#` is the most common reason a search fails or matches nothing.
```
name:david#
name:david# AND (currency:singd# OR last_update:[2023-01-01 TO NOW]#)
```
- **Boolean:** `AND`, `OR`, `NOT`, uppercase, with parentheses for grouping. Use them between clauses (`a:x# AND b:y#`) and inside one clause's terms (`industry_id:1 AND 2 AND 3#`, `fe_id:NOT (1)#`).
- **Text fields.** Unquoted terms mean *contains*; quoted terms mean *exact*: `current_job_title:"Data Engineer"#`. Combine terms inside a clause with operators: `skill:(python OR scala) AND spark#`.
- **Value fields** (`*_id`, `currency`, `status_id`, `deleted`…) take **tenant-specific IDs**. Industry, functional expertise, owner and status IDs differ per Vincere account, so never guess them. Search by the text field instead (`current_job_title`, `skill`, `advanced_text`), or ask the user for the ID.
- **Ranges:** `[a TO b]` is inclusive and `{a TO b]` is exclusive at the start. `TO` is uppercase. `ALL` and `NOW` are static values. Dates accept only `yyyy-MM-dd` or `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` (UTC): `created_date:[2026-01-01 TO NOW]#`, `current_salary:[60000 TO 90000]#`.
- **Radius:** `current_radius:d=25,unit=km,lat=51.5072,lng=-0.1276#` for candidates. Jobs use `location_radius`, contacts `current_radius`/`work_radius`, companies `radius`. You need coordinates. Candidates without a geotagged location are left out, so for a town name use `current_city:` / `current_location_name:` text instead.
- **Escaping `#`:** it's the terminator, so a literal `#` in a term is written `.08`, e.g. `skill:C.08#` for C#. It only matches as part of a dictionary word.
- **Plain-Lucene extras** from the Lucene query syntax: `*` / `?` wildcards (`manag*`), `~` fuzzy (`operat~`), `"a b"~5` proximity, `^` boost, and backslash-escaping of `+ - && || ! ( ) { } [ ] ^ " ~ * ? : \`. Vincere's API spec does **not** document these. Its in-app Advanced Search supports `*` and `~`, but pass-through to the API is unverified, so treat them as best-effort. Standard Lucene rules apply if they do work: no leading wildcard (`*son`), and `NOT` needs something to subtract from (`a# AND NOT b#`, never `NOT b#` alone).
- **`fq`** takes the same syntax as a filter query, e.g. `fq=deleted:0#`. Put stable filters there and the ranked terms in `q`.

**Paging:** `limit` defaults to 25 and has a **max of 100**. `start` is capped at **10,000**. For deeper paging pass `cursorMark=*`, then keep passing the returned `cursorMark` until it repeats.

**Field cheat-sheet** (search fields, from the spec; value = ID/enum, range = numbers/dates):

| Record | Most useful search fields |
|---|---|
| Candidate | `text` (name, email), **`advanced_text`** (name, email, education, work history, **resume**), `name`, `primary_email`, `phone`, `mobile`, `linkedin`, `skill`, `keyword`, `current_job_title`, `job_title` (work history), `current_employer`, `employer` (past), `current_city` / `current_state` / `current_country_code` / `current_postal_code` / `current_location_name`, `current_radius`, `current_salary` / `desired_salary` (range), `created_date` / `last_update` / `last_activity_date` (date range), `deleted`, `status_id`, `owner_id`, `industry_id`, `fe_id` |
| Job | `text` (title, summary, public description, keywords), `job_title`, `job_description`, `company_id`, `contact_id`, `city` / `country_code` / `location_name`, `location_radius`, `salary_from` / `salary_to`, `open_date` / `closed_date` / `created_date`, `job_open_closed_status` (1 open, 0 closed), `active_job_status`, `private_job` (0 public, 1 private), `owner_id` |
| Contact | `text` (name, email), `name`, `email`, `phone`, `mobile`, `linkedin`, `job_title`, `company_id`, `company_name`, `current_city` / `work_city` / `work_country_code`, `work_radius`, `skill`, `created_date` / `last_update`, `owner_id` |
| Company | `text` (company name), `name`, `website`, `linkedin`, `phone`, `headquarter`, `city` / `country_code` / `location_name`, `radius`, `parent_company_id`, `created_date` / `last_update`, `owner_id` |

**Recruiter asks → queries:**
| Ask | `q` |
|---|---|
| Is this person already in Vincere? (dedupe before `create_candidate`) | `primary_email:"ada@example.com"#`, then fall back to `linkedin:ada-lovelace#` (contains) or `name:"Ada Lovelace"#` |
| Python data engineers in London | `advanced_text:python# AND current_job_title:"data engineer"# AND current_city:london#` |
| Java or Kotlin, not currently at Acme | `skill:java OR kotlin# AND current_employer:NOT (acme)#` |
| Candidates added this year | `created_date:[2026-01-01 TO NOW]#` |
| Open jobs at a company | `company_id:12345# AND job_open_closed_status:1#` |
| Contacts at Acme | `company_name:acme#` |

## Guardrail
Production ATS writes — pilot one, confirm, then bulk. A 401 that persists after the automatic refresh means the connection was revoked — reconnect it from Integrations.

## Handoff
ATS write target: enriched candidates → `create_candidate`.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute vincere <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get vincere <method>` returns the live contract + cost). Only the methods listed below are callable.

- `batch(method: str, calls: list, *, stop_on_error: bool = False) -> dict` — Batched get/search/update/create: run one method over many inputs, rate-limited. Each call is a value -> method(value), or {"args": [...], "kwargs": {...}} for multi-arg methods like update_candidate(id, payload). Destructive methods (delete) are refused. See lib/_base.run_ops.
- `create_candidate(payload: dict) -> Any` — POST /candidate — create a candidate.
- `create_candidates_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /candidate for many records, respecting VINCERE_RATE_LIMIT_RPM.
- `get_candidate(candidate_id: str, *, fields: str | None = None) -> Any`
- `get_job(job_id: str, *, fields: str | None = None) -> Any`
- `search_candidates(q: str, *, fl: str | None = None, sort: str | None = None, **params) -> Any` — GET /candidate/search/ — `q` uses Vincere's `field:terms#` syntax; `fl`=returned fields, `sort`=e.g. "created_date desc".
- `search_companies(q: str, *, fl: str | None = None, sort: str | None = None, **params) -> Any` — GET /company/search/.
- `search_contacts(q: str, *, fl: str | None = None, sort: str | None = None, **params) -> Any` — GET /contact/search/.
- `search_jobs(q: str, *, fl: str | None = None, sort: str | None = None, **params) -> Any` — GET /job/search/ — jobs are `job` in Vincere v2 (CONFIRMED — not `position`).
- `set_id_token(id_token: str)` — Swap in a freshly-refreshed id_token (they expire after 1 h).
- `update_candidate(candidate_id: str, payload: dict) -> Any`

<!-- API-SURFACE:END -->

## Bulk writes & rate limits

For large pushes use `create_candidates_batch`. It paces calls to a conservative **60 req/min**
default (well inside Vincere's limits) and returns `{created, failed, total, elapsed_ms}`.
See `crm-bulk-pushes.md` for the cross-CRM guide.
