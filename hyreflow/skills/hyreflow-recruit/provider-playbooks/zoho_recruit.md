---
name: zoho_recruit
description: "Read Zoho Recruit (recruiting ATS/CRM) via its API v2 — search/get Candidates (check the ATS + dedup before paying for external people data), list/search Clients (the agency's customer companies — an outbound exclusion list), and read Job Openings (the JD a search is built from). Use when the user mentions Zoho Recruit, wants to check the ATS before sourcing externally, needs a do-not-contact list built from clients, or wants a job opening turned into search filters. Keys: self-serve OAuth connect — pick your data center and click Connect."
---

# Zoho Recruit — Integration Meta Skill

HOW in `lib/zoho_recruit.py`.

## Auth & config
- **Connect (self-serve OAuth):** dashboard **Integrations → Zoho Recruit**. Where Hyreflow's own Zoho app is enabled, click **Connect** and approve on Zoho's consent screen — nothing to register. Otherwise, register your own **Server-based Application** at `api-console.zoho.com`, set its Authorized Redirect URI to the one shown on the card, paste its **Client ID** and **Client Secret**, pick your **data center** (`us`, `eu`, `in`, `au`, `jp`, `ca`, `sa` or `cn`) and click **Connect**. Either way Hyreflow stores the connection and refreshes the access token itself — no refresh token is ever pasted.
- Read-mostly adapter: search/get Candidates, list/search Clients, list/search/get Job Openings, and `get_fields` to look up an account's real field names.
- Module API names: `Candidates`, `Clients`, `Job_Openings`, `Contacts`. **Field names vary per account** (custom fields, and the job-description field is not standardized) — if you're not sure a field exists, call `get_fields` for the module before guessing.

## Operations
Generic (any module): `list_records`, `get_record`, `search_records`, `get_fields`. Candidates: `search_candidates`, `get_candidate`. Clients: `list_clients`, `search_clients`. Job Openings: `list_job_openings`, `search_job_openings`, `get_job_opening`.

## Search syntax & pagination
- Search takes **exactly one** of `criteria`, `email`, `phone` or `word` — never combine them.
- `criteria` shape: `((Field:operator:value)and(Field:operator:value))`, up to 10 conditions. Operators: `equals`, `not_equal`, `starts_with`, `ends_with`, `contains`, `not_contains`, `in`. **Escape** any comma or parenthesis inside a value with a backslash, or the criteria string parses wrong.
- A search with no match comes back as an empty result (`{"data": []}`) rather than an error — don't treat it as a failure.
- `page`/`per_page` paginate both `list_*` and `search_*`; `per_page` tops out at **200**. Increment `page` until `info.more_records` is false.

## Workflow 1 — search the ATS before going external
Before running `people_search` (or any external provider) for a role, search Zoho Recruit's own Candidates first — it's free (no vendor spend) and avoids re-sourcing someone already in the pipeline:
1. **Dedup by email**: `search_candidates(email="jane@acme.example.com")` — an exact hit means don't re-source her.
2. **Criteria search** on the fields recruiters actually filter by, typically `Current_Job_Title`, `Skill_Set`, `City` — e.g. `criteria="((Current_Job_Title:contains:platform engineer)and(City:equals:Austin))"`. Run `get_fields(module="Candidates")` first if you're not sure those are the account's real field names.
3. **Keyword fallback**: `search_candidates(word="kubernetes")` for a loose, whole-record match when a structured criteria search comes up thin.
Only fall back to an external people-data provider for the gap Zoho Recruit doesn't cover — don't source everything externally and skip the ATS check.

## Workflow 2 — build an outbound exclusion list from Clients
Before running an outbound staffing/BD campaign, pull the agency's own client list and drop those companies from the target list — you don't want to cold-pitch a company that's already a paying client:
1. Page through `list_clients(per_page=200)`, incrementing `page` until `info.more_records` is false.
2. Collect each client's `Client_Name` and website domain (read the field with `get_fields(module="Clients")` if the account's website field isn't obviously named).
3. Match those names/domains against your outbound company list and drop the overlap before you sequence anyone.

## Workflow 3 — turn a Job Opening's JD into search filters
1. Find the opening: `search_job_openings(word="platform engineer")` or `list_job_openings(per_page=200)`, then `get_job_opening(job_opening_id)` for the full record.
2. Read the job-description text off the record. The field holding it isn't standardized across accounts — call `get_fields(module="Job_Openings")` if you don't already know the account's field name for it.
3. Turn that text into `people_search` filters: pull out titles, must-have skills/keywords, locations and a seniority level, then run the waterfall (see [`finding-companies-and-contacts.md`](../finding-companies-and-contacts.md)) — don't paste the raw JD into a provider call.

## Connecting
1. Open the dashboard's **Integrations** page and pick **Zoho Recruit**.
2. If Hyreflow's own Zoho app is enabled, click **Connect** and approve on Zoho's consent screen — done.
3. Otherwise, register your own **Server-based Application** at `api-console.zoho.com`, set its Authorized Redirect URI to the one shown on the card (`https://recruit.hyreflow.ai/api/v2/integrations/zoho_recruit/oauth/callback`), then paste the **Client ID** and **Client Secret**, pick the **data center** your account lives in, and click **Connect**.
4. Hyreflow stores the resulting connection and keeps the access token refreshed — no refresh token is ever pasted.

## Handoff
Zoho Recruit is a read source here, not a write target: its Candidates de-dup sourcing, its Clients drive the outbound exclusion list, and its Job Openings seed `people_search` filters. Sourced + enriched candidates still land in whatever ATS/CRM the agency writes to.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute zoho_recruit <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get zoho_recruit <method>` returns the live contract + cost). Only the methods listed below are callable.

- `get_candidate(candidate_id: str) -> Any` — GET /Candidates/{id}.
- `get_fields(module: str) -> Any` — GET /settings/fields?module= — the account's field API names for a module (custom fields included). Needs scope ZohoRecruit.settings.fields.READ.
- `get_job_opening(job_opening_id: str) -> Any` — GET /Job_Openings/{id} — the full record, including the job description field.
- `get_record(module: str, record_id: str) -> Any` — GET /{module}/{id} — one full record.
- `list_clients(*, page: int | None = None, per_page: int | None = None, fields: str | None = None) -> Any` — GET /Clients — the agency's client companies (Client_Name, Website, …), one page ≤200.
- `list_job_openings(*, page: int | None = None, per_page: int | None = None, fields: str | None = None) -> Any` — GET /Job_Openings — one page of job openings (Job_Opening_Name, Job_Opening_Status, Client_Name…).
- `list_records(module: str, *, page: int | None = None, per_page: int | None = None, fields: str | None = None, sort_by: str | None = None, sort_order: str | None = None) -> Any` — GET /{module} — one page of records (per_page ≤200). `fields` = comma-separated API names.
- `search_candidates(*, criteria: str | None = None, email: str | None = None, phone: str | None = None, word: str | None = None, page: int | None = None, per_page: int | None = None) -> Any` — GET /Candidates/search — e.g. criteria `((Current_Job_Title:contains:engineer)and(City:equals:Austin))`, or email=jane@acme.com for an exact dedup check, or word= for a keyword across the record.
- `search_clients(*, criteria: str | None = None, word: str | None = None, page: int | None = None, per_page: int | None = None) -> Any` — GET /Clients/search — e.g. criteria `(Website:contains:acme.com)` or `(Client_Name:equals:Acme)`.
- `search_job_openings(*, criteria: str | None = None, word: str | None = None, page: int | None = None, per_page: int | None = None) -> Any` — GET /Job_Openings/search — e.g. criteria `(Job_Opening_Status:equals:In-progress)`.
- `search_records(module: str, *, criteria: str | None = None, email: str | None = None, phone: str | None = None, word: str | None = None, page: int | None = None, per_page: int | None = None) -> Any` — GET /{module}/search — exactly one of criteria | email | phone | word. No match → {"data": []}.

<!-- API-SURFACE:END -->
