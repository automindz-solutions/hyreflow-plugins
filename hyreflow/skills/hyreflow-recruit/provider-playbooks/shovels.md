---
name: shovels
description: "US building-permit & contractor data via the Shovels API — search permits and contractors by location + date, resolve addresses/cities/zips to geo_ids, pull contractor employees/permits/metrics, residents, and area metrics. Use when the user mentions Shovels, building permits, construction contractors, or sourcing/recruiting in construction & the trades (electrical, HVAC, roofing, solar). Keys: BYOK required — no hyreflow-managed option."
---

# Shovels — Integration Meta Skill

HOW in `lib/shovels.py`. Paths from docs.shovels.ai (2026-06-01); index: `reference/docs/shovels/raw/endpoints.md`.

## Auth & config
- **Base URL:** `https://api.shovels.ai/v2` · **Auth:** header `X-API-Key` (env `SHOVELS_API_KEY`; never hardcode).
- **Pagination:** cursor — `size` (≤100, default 50) + `cursor` → `next_cursor`; `iter_permits`/`iter_contractors` auto-walk it.
- **Credit-metered** — `get_usage()` to check (safe read-only pilot).

## Core workflow (geo_id first)
Everything keys off a **`geo_id`**. Resolve the place first — `search_addresses` / `search_cities` /
`search_zipcodes` / `search_counties` / `search_jurisdictions` / `search_states` (they return geo_ids) —
then pass `geo_id` to `search_permits` / `search_contractors`. **Both searches REQUIRE `geo_id` +
`permit_from` + `permit_to` (YYYY-MM-DD).**

## Operations
Geo: `search_addresses/cities/counties/jurisdictions/states/zipcodes`. Permits: `search_permits`/`iter_permits`, `get_permit`. Contractors: `search_contractors`/`iter_contractors`, `get_contractor`, `get_contractor_employees`, `get_contractor_permits`, `get_contractor_metrics`. Residents/metrics: `get_address_residents`, `get_address_metrics_current/monthly`, plus city/county/jurisdiction details + metrics. Lists/meta: `list_tags`, `list_zip_codes`, `data_release_date`, `get_usage`. **CONFIRMED:** the two searches + usage; per-record detail/metrics sub-paths are pattern-inferred — verify on first pilot, `request()` covers any that differ.

## Recruitment use (why it's here)
The contractor record has a rich 34-field schema; **how much is populated scales with contractor SIZE.** A **solo operator** returns sparse — name + phone + trade + activity, with email/linkedin/license/revenue/employee_count null. An **established firm** (e.g. ~1,150 permits, 10-49 emp) returns it ALL: **`linkedin_url`** (company), **`email`** (often MULTIPLE, comma-separated — e.g. `…@gmail.com,owner@acme.example.com` → parse the non-free-mail one for the **corporate domain**), multi-value **`phone`**, `dba`, `license`+`classification`+dates, `revenue`, `employee_count`, `primary_industry`, full `address`+`latlng`, `rating`/`review_count`, `tag_tally`. So **email/linkedin/domain ARE provided for real companies** — don't assume they're absent, and don't generalise from a single sparse solo record. → Enrichment routing: **rich record** → parse domain from corporate email + use `linkedin_url` → people-DBs directly (no Exa-resolve needed); **sparse solo record** → name+phone + Exa-resolve+verify. Parsing: `email`/`phone` can be comma-multi-value.
- **Candidate sourcing (CONFIRMED):** many "contractors" are **named individuals / solo operators** (the record carries the person's name + phone) → `search_contractors` by metro+date = a list of directly-contactable individual tradespeople. White-collar (PM/super) candidates *may* also come via `get_contractor_employees` (still UNVERIFIED — confirm its shape on pilot).
- **BD / client acquisition:** same call → active/growing firms → qualify on `employee_count`/`revenue`/`permit_count`/`rating` → pitch recruiting services.
- **Billing (live):** Shovels is BYOK-only — every call is **0 Hyreflow credits**, billed instead against
  the client's own connected Shovels account. `search_contractors` bills the client per record on Shovels'
  own meter → `size` is the cost dial there; a 0-result search costs 0. `get_usage.credits_used` reads the
  client's own Shovels usage.
- **Trade filter:** `contractor_classification_derived="solar"` returned 0 (not free-text) — trade lives in `tag_tally`/`classification_derived` enums; discover valid values via `list_tags` first.
- `search_permits` = project activity as a hiring signal. `job value` is in **cents**.

## ⚠️ Contractor detail sub-tree — 2 of 4 paths usable
- **`get_contractor` (bare `/contractors/{id}`) → 404; don't use it.** The vendor does expose a by-id read (a rich, search-shaped `{items:[...],size}` response), but the route the adapter takes isn't it. Use `search_contractors` instead — it returns the same rich fields for established firms.
- **Email/LinkedIn/domain ARE available** for established contractors (see field richness above); a solo-operator record is sparse — don't generalise from one.
- **`get_contractor_metrics` → errors**, even with dates. Its route is unconfirmed — don't use it.
- **`get_contractor_employees` → THE candidate goldmine.** Per the doc example, each employee is a full individual record: **`name`, `job_title`, `seniority_level`, `department`, `phone`, `email` (PERSONAL), `business_email` (WORK), `linkedin_url` (individual), full address.** So for construction recruiting Shovels is a **purpose-built candidate DB**: contractor (hiring signal) → employees → named tradespeople/staff with personal email + LinkedIn + role/seniority/dept → outreach, **candidate-channel-compliant with NO external enrichment** (use the personal `email` + `linkedin_url`; `business_email` is work-only). Filter the roster by `job_title`/`seniority_level`/`department`. Returned **empty for a solo contractor** (0 employees) — populated for real firms. **Cost: 0 Hyreflow credits (BYOK) — likely billed per-employee-record on the client's own Shovels meter (like permits), so gate with small `size`** (unconfirmed; verify on a populated firm).
- **DUAL-USE — same roster, two directions by CUSTOMER INTENT (prompt first):** the employee list serves either (a) **candidate sourcing** — the staff are people to poach/place → target placeable roles, use **personal `email` + `linkedin_url`**; or (b) **BD / decision-maker mapping** — find who to pitch recruiting services to → target senior/leadership + dept heads, use **`business_email`** (work). Slice by `seniority_level`/`department`/`job_title`. This is the same email-type-by-context rule (candidate→personal, BD→work) applied within one record. **Ask the customer which (or both) before pulling.**
- **🔴 EEO COMPLIANCE — hard rule:** the employee record also carries a consumer overlay (`gender`, `age_range`, `is_married`, `has_children`, `income_range`, `net_worth`, `homeowner`). **NEVER use these to screen/filter/target candidates** — gender/age/marital/parental status in hiring = illegal employment discrimination (US EEO). Candidate selection uses ONLY `job_title`/`seniority_level`/`department`/location/skills.
- **`get_contractor_permits` → works, rich per-permit property data — but ⚠️ billed PER PERMIT on the client's own Shovels meter and returns ALL the contractor's permits** (0 Hyreflow credits either way, but a large contractor's permit count runs up the client's own bill fast). Cost trap — gate `size` / expect per-record billing.
- **Email/LinkedIn are NOT exposed by the contractor API** (search nulls aren't filled by any working detail call) → phone is the only contact from Shovels; enrich email/linkedin externally (FullEnrich/LeadMagic/Wiza).

## Handoff
Sourcing/signal layer (construction): Shovels finds active contractors/permits → qualify vs ICP →
enrich contacts (waterfall) → sequence / push to ATS. Pairs with the standard pipeline.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface — `lib/shovels.py`
Run via the CLI: `hyreflow tools execute shovels <method> --payload '{...}'` — method names + params are in the **Callable surface** block above; preview with `--dry-run`. (Engine base: `https://api.shovels.ai/v2`; any unwrapped endpoint is reachable through the tool's generic `request` passthrough.)
- `data_release_date() -> Any` — GET /meta/release — latest data release date (inferred sub-path).
- `get_address_metrics_current(geo_id: str, **params) -> Any` — GET /addresses/{geo_id}/metrics/current (inferred).
- `get_address_metrics_monthly(geo_id: str, **params) -> Any` — GET /addresses/{geo_id}/metrics/monthly (inferred).
- `get_address_residents(geo_id: str, **params) -> Any` — GET /addresses/{geo_id}/residents — residents at an address (homeowner field) (inferred).
- `get_city(geo_id: str) -> Any` — GET /cities/{geo_id} — city details (inferred).
- `get_city_metrics_current(geo_id: str, **params) -> Any`
- `get_city_metrics_monthly(geo_id: str, **params) -> Any`
- `get_contractor(contractor_id: str) -> Any` — GET /contractors/{id} — contractor profile (inferred path; verify).
- `get_contractor_employees(contractor_id: str, **params) -> Any` — GET /contractors/{id}/employees — employee/contact data (inferred).
- `get_contractor_metrics(contractor_id: str, **params) -> Any` — GET /contractors/{id}/metrics — filtered metrics for a contractor (inferred).
- `get_contractor_permits(contractor_id: str, **params) -> Any` — GET /contractors/{id}/permits — permits a contractor worked on (inferred). May need permit_from/to.
- `get_county(geo_id: str) -> Any`
- `get_county_metrics_current(geo_id: str, **params) -> Any`
- `get_county_metrics_monthly(geo_id: str, **params) -> Any`
- `get_jurisdiction(geo_id: str) -> Any`
- `get_jurisdiction_metrics_current(geo_id: str, **params) -> Any`
- `get_jurisdiction_metrics_monthly(geo_id: str, **params) -> Any`
- `get_permit(permit_id: str) -> Any` — GET /permits/{id} — a single permit by id.
- `get_usage() -> Any` — GET /usage — API usage / credits (safe read-only pilot).
- `iter_contractors(*, geo_id: str, permit_from: str, permit_to: str, **params) -> Iterator[dict]`
- `iter_permits(*, geo_id: str, permit_from: str, permit_to: str, **params) -> Iterator[dict]` — Auto-paginate /permits/search across all cursor pages.
- `list_tags(**params) -> Any` — GET /lists/tags — all available permit tags (inferred sub-path).
- `list_zip_codes(**params) -> Any` — GET /lists/zipcodes — all available zip codes (inferred sub-path).
- `search_addresses(**params) -> Any` — GET /addresses/search — resolve an address → geo_id (+ details).
- `search_cities(**params) -> Any` — GET /cities/search — resolve cities → geo_ids.
- `search_contractors(*, geo_id: str, permit_from: str, permit_to: str, **params) -> Any` — GET /contractors/search — REQUIRES geo_id + permit_from + permit_to. Ordered by most-recent
- `search_counties(**params) -> Any` — GET /counties/search.
- `search_jurisdictions(**params) -> Any` — GET /jurisdictions/search.
- `search_permits(*, geo_id: str, permit_from: str, permit_to: str, **params) -> Any` — GET /permits/search — REQUIRES geo_id + permit_from + permit_to (YYYY-MM-DD). One page.
- `search_states(**params) -> Any` — GET /states/search.
- `search_zipcodes(**params) -> Any` — GET /zipcodes/search.

<!-- API-SURFACE:END -->
