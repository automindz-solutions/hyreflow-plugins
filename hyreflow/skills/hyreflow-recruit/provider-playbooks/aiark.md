---
name: aiark
description: "B2B data via the AI Ark API — company & people search, reverse lookup (email/phone → person), mobile phone finder, personality analysis, and async export + email-finder flows. Use when the user mentions AI Ark, sourcing people/companies, or finding mobiles/emails at scale. Keys: hyreflow-managed credits or BYOK (bring your own AI Ark API key)."
---

# AI Ark — Integration Meta Skill

The full filter shape + a worked example live in the **Filter structure** section below (and in
`tools get aiark people_search` → `details`). The vendor OpenAPI is cached engine-side only — it is **not
shipped with this skill**, so don't send users to a `reference/docs/...` path; rely on this playbook.

## Auth & config
- **Base URL:** `https://api.ai-ark.com/api/developer-portal/v1` · **Auth:** header `X-TOKEN` (env `AIARK_API_KEY`; never hardcode).
- **Rate limits:** 5 req/s · 300/min · 18,000/hr.
- **All paths CONFIRMED** from docs.ai-ark.com (ReadMe `.md` + `llms.txt`, Tier-2 plain HTTP). Watch the shapes: company search = `POST /v1/companies` (**plural**), email finder = `POST /v1/people/email-finder`, async status/results use **`{trackId}` path segments** and the results path is **`/inquiries`**, credits = `GET /v1/payments/credits`. (Full endpoint index + people-search enums are cached engine-side, not shipped with this skill.)

## Filter structure (critical — read before hand-building a payload)
People search body = `{account, contact, lists, page, size}`; **`page` (0-based) and `size` (≤100) are required**. Each `account`/`contact` filter takes an `any` and/or `all` wrapper, each with `include`/`exclude`. **The `include`/`exclude` VALUE differs by filter type — this is the #1 footgun:**

- **Text filters** → `include` is a **SINGLE OBJECT** `{ "mode": "SMART"|"WORD"|"STRICT", "content": [...] }`. Fields: account `name`, `url`, `productAndServices`, `industries`, `technologies`; contact `fullName`, `skill`, `certification`, `title` (under `experience.{latest,current,previous}`), `education.degree`, `education.fieldOfStudy`, `language`. (Mode enum is SMART/WORD/STRICT — **not "FUZZY"**.)
  - ✅ correct: `"skill": {"any": {"include": {"mode":"SMART","content":["Python","FastAPI"]}}}`
  - ✅ master's degree: `"education": {"degree": {"any": {"include": {"mode":"SMART","content":["Master"]}}}}`
  - ❌ 400 `request not readable`: `include` as an **array** → `{"any":{"include":[{"mode":"SMART","content":["Python"]}]}}`
  - ❌ **silently ignored** (full DB, still billed): bare `{"mode","content"}` with no `any/all`+`include` wrapper, or a title at `contact.title` instead of `experience.*.title`.
  - `any` = OR, `all` = AND across the `content` terms.
  - **`contact.skill` = the `people_search` canonical `skills` field** (the waterfall maps `skills` → `contact.skill`). For IT/role sourcing prefer it over title-only filtering — it prefilters at the source instead of broad-pull + client-side filtering of the returned `skills[]`. `certifications` maps to `contact.certification`.
- **Experience duration filters** live under `contact.experience.{latest,current,previous}.duration`. For total career experience, use `contact.experience.current.duration.total.min.{year,month}` (for example, 5+ total years: `"experience":{"current":{"duration":{"total":{"min":{"year":5}}}}}`). Do not confuse this with current-job tenure; `total` is the total-experience bucket.
- **String / enum filters** → `include` is a **BARE ARRAY of strings** `["..."]` (e.g. account `domain`, `linkedin`, `location`, `naics`, `technology`, `type`; contact `seniority`, `departmentAndFunction`, `socialMedia`, `profileBadge`). E.g. `"location": {"any": {"include": ["Berlin","Berlin, Germany"]}}`.

**Detect a silently-ignored filter:** read `response["result"]["totalElements"]` (the count lives under the `result` envelope — see **Response shape** below). Take a location-only baseline, then add your filter — if the total does NOT drop, the filter was ignored (wrong shape). Verified: Berlin location-only ≈ 752,080 → + `skill` as object ≈ 39,258 → + title ≈ 276.

**Worked example** (peek the count with `size:1` before pulling depth):
```json
{"contact": {
   "location": {"any": {"include": ["Berlin","Berlin, Germany","Berlin Metropolitan Area"]}},
   "skill": {"all": {"include": {"mode":"SMART","content":["Python","FastAPI"]}}},
   "education": {"degree": {"any": {"include": {"mode":"SMART","content":["Master"]}}}},
   "experience": {"current": {
      "title": {"any": {"include":
         {"mode":"SMART","content":["Backend Engineer","Backend Developer","Software Engineer"]}}},
      "duration": {"total": {"min": {"year": 5}}}
   }}
 }, "page": 0, "size": 1}
```
> **Easier:** the `people_search` waterfall builds this shape for you from a canonical query —
> `tools execute people_search --payload '{"providers":["aiark"],"skills":["Python","FastAPI"],"titles":["Backend Engineer"],"locations":["Berlin"]}'`.
> Only hand-build the raw `aiark people_search` payload when you need a filter the canonical query can't express.

**Canonical waterfall fields → AI Ark filter (ENG-160).** Beyond the portable fields (`titles`, `locations`,
`seniority`, `skills`, `certifications`, `min_experience_years`, `company_names/domains/linkedin_urls`), the
waterfall now maps these **AI-Ark-only** fields — passing any of them **pins the chain to AI Ark** (the other
providers can't honor them, so they're skipped rather than silently returning non-matching people):

| Canonical field | AI Ark filter | Notes |
|---|---|---|
| `company_tenure_min_months` / `_max_months` | `contact.experience.current.duration.currentCompany` | tenure AT the company; **`max` = "joined ≤ N months ago"** (the newly-hired filter) |
| `role_tenure_min_months` / `_max_months` | `…duration.currentJob` | tenure in the current title (resets on internal move) |
| `min_experience_years` (existing) | `…duration.total.min.year` | whole-career experience, years |
| `profile_badges` | `contact.profileBadge` | enum[]: VERIFIED / OPEN_TO_WORK / HIRING / INFLUENCER / CREATOR / PREMIUM |
| `departments` | `contact.departmentAndFunction` | enum[] (200+): e.g. `master_sales`, `business_development`, `software_development` |
| `company_founded_year_min` / `_max` | `account.foundedYear` | RANGE — **single `{start,end}` object**: `{"type":"RANGE","range":{start,end}}` — the one exception to the array-under-`range` pattern below, don't copy it for employeeSize/revenue |
| `company_employee_min` / `_max` | `account.employeeSize` | RANGE — **wrapped, array under `range`**: `{"type":"RANGE","range":[{start,end}]}` — ❌ a bare array (`{"employeeSize":[{start,end}]}` with no `type`/`range` wrapper) 400s: `AiArkError: AI Ark API 400: request not readable` |
| `company_revenue_min` / `_max` | `account.revenue` | RANGE — **wrapped, array under `range`**: `{"type":"RANGE","range":[{start,end}]}` (see worked example under Company search filters) |
| `company_funding_types` | `account.funding.type` | enum[]: PRE_SEED…SERIES_J, VENTURE_ROUND, ANGEL, … |

Tenure is expressed in **months** and split into `{year, month}` (e.g. 18 → `{"year":1,"month":6}`). Enum
values (`profile_badges`, `departments`, `company_funding_types`) are passed through verbatim — invalid enums
are silently ignored by AI Ark (not a 400), so use the exact catalog values.
- **Field-name corrections vs an earlier inferred note:** the contact location field is **`contact.location`** (not `contactLocation`); company filters live under `contact.company.{latest,current,previous}` by UUID; titles/durations live under `contact.experience.{latest,current,previous}`; degree filters live under `contact.education.degree`.
- **Candidate signal — `contact.profileBadge` (OPEN_TO_WORK):** source candidates flagged *open to work* with `{"contact":{"profileBadge":{"any":{"include":["OPEN_TO_WORK"]}}}}`. **AI Ark is the only DB in the stack with this badge filter, so route any "open to work" candidate request here.** (`ProfileBadgeEnum` also has VERIFIED/INFLUENCER/CREATOR; `HIRING` is a company/BD signal, not a candidate one — don't use it for candidate sourcing.) Pair it with a title/location/skill — `OPEN_TO_WORK` alone matches a ~24M global pool.
- Enum lists (SeniorityLevel, DepartmentAndFunction, Industry, CompanyType, ProfileBadge, Language, TimeFrame) are in the cached spec.
- **⚠️ Location is an EXACT-string filter — enumerate the whole metro, not just the headline city.** `contact.location` (and `geoLocation` aside) matches the strings you pass; "San Francisco Bay Area" does NOT auto-include its cities. When targeting **the Bay Area, always include**: `["San Francisco", "San Francisco Bay Area", "Menlo Park", "Palo Alto", "Mountain View", "Sunnyvale", "Cupertino", "Santa Clara", "Redwood City", "Oakland", "Berkeley", "San Jose"]` (Palo Alto especially — it's where a lot of Big-Tech HQs/staff sit and was missed by an SF-only list). Same principle for any metro (NYC → add Brooklyn/Jersey City; London → add Greater London etc.). **⚠️ `geoLocation` (lat/lng+radius) is an ACCOUNT (company-HQ) filter, NOT a contact filter** (LIVE-confirmed: putting it under `contact` is silently ignored → nationwide results; under `account` it filters by the person's COMPANY location within the radius). **To filter the PERSON's location, use `contact.location` (str[] exact-string, NO radius)** — enumerate the metro's city strings. Use `account.geoLocation` only when "within X km of a point" by company HQ is acceptable.

## Company search filters
Company search body = `{account, page, size}`; **`page` (0-based) and `size` (≤100) are required**. Use `company_search` when account-level filters are the primary target; use the `people_search` waterfall when the end goal is candidate sourcing.

**Firmographic account filters** use raw AI Ark shapes. AI Ark silently ignores unknown fields or wrong wrappers, so prefer these documented wrappers and validate that `result.totalElements` drops from a baseline before pulling depth:

- Funding round type:
```json
{"account":{"funding":{"type":["SEED"]}},"page":0,"size":1}
```
  Enum examples: `PRE_SEED`, `SEED`, `SERIES_A`..`SERIES_J`, `VENTURE_ROUND`, `ANGEL`, `PRIVATE_EQUITY`, `DEBT_FINANCING`, `GRANT`, `CORPORATE_ROUND`, etc.
- Funding date/amount ranges:
```json
{"account":{"funding":{"duration":{"start":"1704067200000","end":"1735689599000"}}},"page":0,"size":1}
```
  `duration.start` / `duration.end` are epoch-ms strings. `account.funding.totalAmount` and `account.funding.lastAmount` also accept `{start,end}` range objects.
- Revenue:
```json
{"account":{"revenue":{"type":"RANGE","range":[{"start":1000000,"end":10000000}]}},"page":0,"size":1}
```
  `type` enum is `ALL` | `NONE` | `RANGE`; `range` is an **ARRAY** of `{start,end}` objects, not a single object.
- Account language:
```json
{"account":{"language":{"any":{"include":["german"]}}},"page":0,"size":1}
```
  The language enum is provider-owned and currently 48 AI Ark values; use provider values as supplied by AI Ark.
- Founded year:
```json
{"account":{"foundedYear":{"range":{"start":2018,"end":2024},"type":"RANGE"}},"page":0,"size":1}
```
  Preserve the `range` object plus `type:"RANGE"` shape.

**Department headcount metric filters** live at `account.metric` and accept arrays:
- `account.metric.growth[]` = percent headcount growth in a department over a timeframe.
- `account.metric.employee[]` = absolute number of people in a department; `start` is the minimum and `end` is the maximum.

Each metric item shape:
```json
{"function":["sales"],"start":10,"end":20,"timeFrame":"THREE"}
```
- `function`: array of department/function enums.
- `start`, `end`: numeric range bounds.
- `timeFrame`: `ONE`, `THREE`, `SIX`, `TWELVE`, `TWENTY_FOUR`; default `TWELVE`.
- Department/function enum: `program_and_project_management`, `education`, `purchasing`, `accounting`, `sales`, `research`, `operations`, `customer_success_and_support`, `legal`, `product_management`, `media_and_communication`, `real_estate`, `quality_assurance`, `consulting`, `arts_and_design`, `healthcare_services`, `entrepreneurship`, `engineering`, `community_and_social_services`, `marketing`, `information_technology`, `business_development`, `administrative`, `military_and_protective_services`, `finance`, `human_resources`, `support`.

Live-confirmed examples (peek counts with `size:1`):
```json
{"account":{"metric":{"growth":[{"function":["sales"],"start":10,"end":20,"timeFrame":"THREE"}]}},"page":0,"size":1}
```
Returned `totalElements` 42,102 vs baseline 72,155,668.

```json
{"account":{"metric":{"employee":[{"function":["sales"],"start":5,"end":20,"timeFrame":"TWELVE"}]}},"page":0,"size":1}
```
Returned `totalElements` 761,948 vs baseline 72,155,668.

**Response shape:** every `tools execute` call returns the **engine envelope** `{ "_meta": { credits_charged, balance, run_id, … }, "result": <raw vendor payload> }`. The AI Ark search payload sits **inside `result`**: `result = { content: [...people...], pageable, totalElements, totalPages, number, size, trackId, first, last, empty }` — read people at `response["result"]["content"]`, the match count at `response["result"]["totalElements"]`, and the find-emails **`trackId` at `response["result"]["trackId"]`**. (Reading these at the top level returns `None` — that's the classic count-peek "empty result" gotcha.) This envelope is standard for every tool, not just AI Ark. Errors: `404` data-not-found; `501` = `socialMediaFollower` on a non-LinkedIn platform (only `linkedin` supported).

## Async flows
- **Export people:** `export_people` → trackId → poll `export_statistics` (DONE) → `export_results` (paginated).
- **Find emails:** `people_search` (returns trackId) → `find_emails({trackId, webhook})`. ⚠️ **`webhook` is REQUIRED** (verified live: omitting → 400 'webhook is required') — results are **pushed to your webhook**, there is NO local poll-and-fetch, so this needs a hosted receiver. trackId single-use, ~6h.

## ⚠️ WORK EMAIL ONLY — not for candidate workflows
AI Ark's email-finder returns **work / professional emails only — NOT personal emails.** Do **not** use AI Ark
for personal-email or **candidate-acquisition** workflows. **Personal emails come from `fullenrich` or
`leadmagic` only** (COO-confirmed). AI Ark is for sourcing + work-email/mobile enrichment.

## Guardrails
- `mobile_phone_finder` is expensive (10 credits) — use only on high-confidence matches. `fetch_credit()` = safe read-only pilot. Pilot small; gate bulk export/find-emails.

## Handoff
Sourcing + enrichment: company→people search → email/phone (export/find-emails or mobile finder) → ATS/sequencer. Discover companies first, then people.


## Field notes (production experience)

> **Field-shape note:** these are vendor-native operational notes describing the **raw vendor JSON** — the shape that sits **inside** the engine's `result` envelope. The vendor payload itself is not normalized (no `result.data.` re-nesting of vendor fields), but `tools execute` still wraps it as `{ _meta, result }`, so access every field under `result` (e.g. `result.content`, `result.totalElements`) — see **Response shape** above.

**Base URL — RESOLVED (official OpenAPI):** server is `https://api.ai-ark.com/api/developer-portal`; the people-search path is `/v1/people`, so the full URL is `.../developer-portal/v1/people`. Our `BASE_URL` folds `/v1` in and `people_search` posts to `people` — confirmed correct. (The earlier "no /v1" ambiguity is settled: `/v1` lives in the path.)

> The filter shapes, mode enum (`SMART`/`WORD`/`STRICT`), field names, and response shape are now documented from the spec in the **Filter structure** section above — that supersedes an earlier inferred note's `FUZZY`/`contactLocation` wording, which was inaccurate.

**Credit costs:** company search 3/result; people search 3/result; reverse lookup 5/req;
**mobile phone finder 10/req** (use only after a high-confidence match); export/email-finder 3/result;
polling, statistics, results = **free**.

**Async (export_people / find_emails):** launch -> `trackId` -> poll `*_statistics` until `state:"DONE"` -> fetch `*_results` (paginated).
`find_emails` trackId is **single-use, expires 6h** after the `people_search` that generated it.

**Pagination:** zero-based `page` + `size` (search/export use JSON body; results browsing uses query params).
**Errors:** `409` = you fetched results while the async job is still running (poll statistics first); `404` = profile not found; `429` = rate limit (resets every 60s; limits 5/s, 300/min, 18k/hr).
**Constraints:** export max 10,000 results; webhooks auto-retry up to 30x (respond `200` immediately, HTTPS only).

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface — `lib/aiark.py`
Run via the CLI: `hyreflow tools execute aiark <method> --payload '{...}'` — method names + params are in the **Callable surface** block above; preview with `--dry-run`. (Engine base: `https://api.ai-ark.com/api/developer-portal/v1`; any unwrapped endpoint is reachable through the tool's generic `request` passthrough.)
- `company_search(payload: dict) -> dict` — POST /v1/companies — company search (CONFIRMED). Body: filters + page (0-based) + size (<=100).
- `email_finder_results(track_id: str, *, page: int | None = None, size: int | None = None) -> dict` — GET /v1/people/email-finder/{trackId}/inquiries — paginated results
- `email_finder_statistics(track_id: str) -> dict` — GET /v1/people/email-finder/{trackId}/statistics — job status (free, CONFIRMED).
- `export_people(payload: dict) -> dict` — POST /v1/people/export — async export (filters + page + size 1..10000 + `webhook`).
- `export_results(track_id: str, *, page: int | None = None, size: int | None = None) -> dict` — GET /v1/people/export/{trackId}/inquiries — paginated export results
- `export_single(payload: dict) -> dict` — POST /v1/people/export/single — export one person with email by `id` OR `url` (CONFIRMED).
- `export_statistics(track_id: str) -> dict` — GET /v1/people/export/{trackId}/statistics — export job status (free, CONFIRMED).
- `fetch_credit() -> dict` — GET /v1/payments/credits — remaining credits (read-only, safe pilot; CONFIRMED).
- `find_emails(payload: dict) -> dict` — POST /v1/people/email-finder — async email finder from a prior people_search `trackId`.
- `mobile_phone_finder(payload: dict) -> dict` — POST /v1/people/mobile-phone-finder — mobile by `linkedin` OR `domain`+`name` (+`type`).
- `people_analysis(payload: dict) -> dict` — POST /v1/people/analysis — personality analysis from a LinkedIn profile `url` (CONFIRMED).
- `people_search(payload: dict) -> dict` — POST /v1/people — people search (CONFIRMED path). Strict nested filter structure:
- `reverse_lookup(payload: dict) -> dict` — POST /v1/people/reverse-lookup — look up a person by email/phone via `search` (CONFIRMED).
- `save_list(payload: dict) -> dict` — POST /v1/lists — create/update a list (up to 10k items) for use in the people_search

<!-- API-SURFACE:END -->
