---
name: prospeo
description: "Email & phone finding + people/company data via the Prospeo API — work email finder, domain search, mobile finder, LinkedIn/social enrichment, email verifier. Use when the user mentions Prospeo or finding/verifying emails & phones. Keys: hyreflow-managed credits or BYOK."
---

# Prospeo — Integration Meta Skill

HOW in `lib/prospeo.py`. Docs cached at `reference/docs/prospeo/raw/`.

## Auth & config
- **Base URL:** `https://api.prospeo.io` · **Auth:** header `X-KEY` (env `PROSPEO_API_KEY`; never hardcode). All endpoints POST + JSON; consume credits on a found result.

## Operations (ALL CONFIRMED from prospeo.io/api-docs, 2026-06-01)
**Live:** `enrich_person` (`/enrich-person` — `data{first_name,last_name,full_name,linkedin_url,email,company_name,company_website,company_linkedin_url,person_id}` + `only_verified_email`/`enrich_mobile`/`only_verified_mobile`), `bulk_enrich_person` (≤50), `enrich_company`, `bulk_enrich_company` (≤50), `search_person` (200M+ contacts, 30+ filters), `search_company` (30M+), `search_suggestions`, `account_information` (safe pilot). Endpoint index: `reference/docs/prospeo/raw/endpoints.md`.

## ⚠️ Deprecation
`email_finder`, `domain_search`, `mobile_finder`, `social_url_enrichment`, `email_verifier`, `linkedin_email_finder` are **deprecated (sunset 2026-03-01)** — kept as thin wrappers but **migrate to `enrich_person`/`search_person`**. `enrich_person(enrich_mobile=True)` = 10 credits (vs 1 for email).

## ⚠️ WORK EMAIL ONLY — not for candidate workflows
Prospeo returns **work / professional emails only — it does NOT find personal emails.** Do **not** use it
in personal-email or **candidate-acquisition** workflows (recruiting candidates → personal email + LinkedIn).
**Personal emails come from `fullenrich` or `leadmagic` only** (COO-confirmed). Prospeo is for BD / work-email use.

## Handoff
Enrichment layer (**work email**): shortlist → Prospeo for work emails/phones → validate → ATS/sequencer.


## Field notes (production experience)

> **Field-shape note:** these are vendor-native operational notes. The client returns the **raw vendor JSON** and uses the method names in this file — read field shapes accordingly (no normalized-wrapper / `result.data.` prefix).

- **Flow (LIVE-CONFIRMED 2026-06-02):** `search_suggestions` (FREE) to resolve canonical filter values → `search_person`/`search_company` to build lists → `enrich_person`/`enrich_company` for email/mobile. Search results **never include email/mobile** — enrich the `person_id`s afterward (`bulk_enrich_person` ≤50).
- **Company lookalikes (LIVE-CONFIRMED 2026-06):** the right flow is **enrich → verify → lookalike**:
  1. `enrich_company` to resolve a seed to its `company_id` — **payload needs the `data` wrapper**: `{"data":{"company_website":"acme.com"}}` (top-level fields → `400 Field required`). Prefer `company_linkedin_url` (most unique) or a clean own-domain; see `reference/docs/prospeo/raw/enrich-company.md`.
  2. **VERIFY the resolved seed** — confirm the returned `company.name`/`domain` is the company you meant. ⚠️ Bare shared-SaaS domains (`personio.com`/`.de`) match the *wrong* company (they appear in many firms' records → resolved to *Aion Bank* / *kiutra* live). A unique domain works: `automindz-solutions.com` → *Automindz Solutions* ✅.
  3. `search_company` with `{"filters":{"company_lookalike":{"company_oids":["<company_id>"],"same_language":false,"minimum_tier":"T1|T2|T3"}},"page":1}`. **`minimum_tier`** is a threshold: **T1** almost-identical (smallest pool) · **T2** similar · **T3** broader (largest). It grows the *total* pool, not the most-similar page-1 order (LIVE: Aion 1968→2552→2872; AutoMindz T1=T2=2170). Returns companies (then people_search + enrich each as usual). Quality is high (Stripe→payments peers; AutoMindz→AI-recruiting peers).
- **`search_person` payload:** `{"filters":{...},"page":N}`. The engine auto-corrects the common shape/enum slips before the call (bare array → `{include:[...]}` on IncludeExclude filters; a stray `{include:[...]}` off `company_headcount_range`; spelling of a real enum value like `Founder-Owner` → `Founder/Owner`) and reports them in the response `_meta.normalized` — but build the correct shapes anyway (unknown values still 400). Key filters:
  - `person_job_title`: `{include:[...], match_mode:"CONTAINS"|"EXACT"|"SIMILAR", smart_intensity:"LOOSE|NORMAL|STRICT"(SIMILAR only), boolean_search:"(CEO OR CTO) AND !intern"}`. Default to `CONTAINS`. `boolean_search` can't combine with include/exclude.
    **⚠️ SIMILAR expands only within the seed title's seniority level** — SIMILAR `"Software Engineer"` +
    `person_seniority ["Senior"]` = ∅ globally (never reaches "Senior Software Engineer"). **Pairing a
    title with `person_seniority`? Use CONTAINS** (substring crosses levels; seniority supplies precision).
  - **`person_location_search`: `{include:[...], exclude:[]}` — values MUST be canonical strings from `search_suggestions({location_search:"munich"})`** (arbitrary strings rejected with `INVALID_FILTERS`). Types: COUNTRY/STATE/CITY/**ZONE**.
  - `person_seniority`: `{include:[...]}` — enum (verbatim): Founder/Owner · C-Suite · Partner ·
    Vice President · Head · Director · Manager · Senior · Entry · Intern. **⚠️ It's `"C-Suite"`, not
    `"C-Level"`** (wrong value → INVALID_FILTERS).
  - `person_department`: `{include, exclude}` of verbatim department names. Top levels: C-Suite ·
    Product · Engineering & Technical · Design · Education & Coaching · Finance · Human Resources ·
    Information Technology · Legal · Marketing · Medical & Health · Consulting · Sales · Operations
    (full hierarchy incl. sub-departments in the cached raw docs). A top-level value auto-includes all
    its sub-departments; a specific sub-level value (e.g. `"Graphic / Visual / Brand Design"`) targets
    just that niche. `person_year_of_experience`: `{min, max}` (years).
  - **⚠️ NO person-level profile-keyword/skills filter (verified live 2026-07-02).** `person_search` is
    NOT profile-wide (C-Suite + SF + `person_search:["Python"]` → NO_RESULTS; it appears to match
    names/titles only), and `company_keywords` scopes COMPANIES, not people. "People with `<skill>` in
    their profile" → **AI Ark** (skills filter); use Prospeo for title/seniority/location/company/firmographic scoping.
  - Company filters (shapes verified 2026-07-02): `company_headcount_range` = **bare array** of buckets
    (`"1-10"`…`"10000+"`); `company_industry` / `company_technology` = `{include, exclude}` of verbatim
    enum values; `company_founded` = `{min, max, include_unknown_founded}`; `company_revenue` = `{min, max}`
    bucket **strings** (`"<100K"`); `company_headcount_growth` = `{timeframe_month, min, max, departments[]}`
    — **⚠️ its `departments` use a DIFFERENT 19-value enum, NOT person_department values, case-sensitive**
    (Medical · Sales · HR · Legal · Marketing · Finance · **Technical** · Consulting · Operations · Product ·
    General management · Administrative · Customer service · Project management · Design / UI / UX ·
    Research · Trades · Real estate · Education; engineering growth = `"Technical"`, HR growth = `"HR"` —
    `"Engineering & Technical"`/`"Human Resources"`/`"Customer Service"` → INVALID_FILTERS here);
    `company_type` = rich object shared by `search_company` and company-scoped `search_person`: `status`
    is one of `Private` / `Public` / `Non-profit` / `Other`; `business_model` is an array of
    `b2b|b2c|b2b2c|d2c|franchise|government`; subverticals such as SaaS, FinTech, HealthTech,
    Marketplace, AI/ML, E-commerce, etc. go under `subtypes.include`; boolean flags are `is_retail`,
    `is_marketplace`, `is_mainly_ai`, `is_mainly_crypto`, `multi_product`, `has_free_tier`,
    `is_self_serve`, `is_sales_led`, `has_usage_pricing`, `has_subscription`, `has_enterprise_plan`,
    `has_public_pricing`. **"SaaS companies" maps to
    `{"company_type":{"subtypes":{"include":["SaaS"]}}}` — NOT `company_type.business_model`.**
    Compact examples:
    `search_company`: `{"filters":{"company_type":{"status":"Private","subtypes":{"include":["SaaS","FinTech"]},"business_model":["b2b"],"has_free_tier":true},"company_headcount_range":["51-100","101-200"]},"page":1}`;
    company-scoped `search_person`: `{"filters":{"person_seniority":{"include":["C-Suite"]},"company_type":{"subtypes":{"include":["SaaS"]},"business_model":["b2b"],"has_public_pricing":true}},"page":1}`.
    Full enum lists
    (~250 industries, full technology list, funding stages) + a complete example payload: cached raw docs
    (`search-person-filters.md`). **⚠️ funding + hiring-signal filters are vendor-side under maintenance
    (2026-07) — and `company_funding` is a verified SILENT NO-OP: it accepts any value (even garbage)
    and filters nothing, so results look filtered but aren't. Never use it; funding-stage sourcing → AI Ark.**
  - **🎯 `company_industry` vs `company_type` — where a company descriptor goes:** resolve each descriptor
    against `company_industry` first (the ~250-value enum via `search_suggestions`). (1) Single clean
    primary industry → `company_industry.include`. (2) **No** industry match, OR pairing it with another
    industry value would OR-broaden instead of AND-narrow → route it to `company_type` (`subtypes.include`
    for a type/vertical like Consulting / SaaS / FinTech / Agency / Professional Services; `business_model`
    for `b2b`/`b2c`). (3) User explicitly says "business model" / "business type" → `company_type`.
    **Don't stall and ask the user to disambiguate — apply the rule.** `company_industry.include` values
    OR together (a 2nd value widens the net); `company_type` ANDs against the industry (it narrows). E.g.
    **"b2b consulting business in the financial services industry"** → keep the clean industry, put the
    cross-cutting descriptors in `company_type` — NOT a second industry value:
    `{"filters":{"company_industry":{"include":["Financial Services"],"exclude":[]},"company_type":{"subtypes":{"include":["Consulting"]},"business_model":["b2b"]}},"page":1}`.
  - **`company_location_search`: `{include:[...], exclude:[]}` — use this for company/account geography
    in both `search_company` and `search_person` company filters. Values MUST be canonical `name` strings
    from `search_suggestions({location_search:"..."})` (COUNTRY/STATE/CITY/ZONE), same as
    `person_location_search`. Difference: `company_location_search` filters where the company is located;
    `person_location_search` filters where the person/contact is located. Do not use a nested
    `company.location` shape. Compact company-search example:
    `{"filters":{"company_location_search":{"include":["Germany","Greater Munich Metropolitan Area, Germany"],"exclude":[]},"company_headcount_range":["51-100","101-200"],"company_industry":{"include":["Software Development"],"exclude":[]}},"page":1}`.**
  - **The ` #<COUNTRY_CODE>` suffix** sometimes seen on locations in UI-built payloads
    (`"San Francisco, California #US"`) **is UI-internal — the API returns and accepts plain canonical
    suggestion names** (live-verified 2026-07-02: C-Suite + `"San Francisco, California"` → 16,155 matches).
  - **⚠️ Can't search with `exclude`-only — need ≥1 positive filter.**
- **🎯 RADIUS trick:** for "within ~X km of a city," use the **ZONE** suggestion (e.g. `"Greater Munich Metropolitan Area, Germany"`) — it covers the metro in ONE value, no town enumeration (unlike AI Ark `contact.location` / Lemlist which need city lists). Confirmed: Steuerfachwirt + Munich ZONE → 66 matches.
- **Credits — two billing systems, don't conflate:** on Hyreflow-managed keys, Prospeo methods are
  **0 credits** under current pricing (free-to-us on the partner plan). The VENDOR-side billing (only relevant
  for BYOK keys): `search_suggestions` = **FREE** (15 req/s); `search_person` = **1 vendor credit per
  page of 25** that returns ≥1 result, **dedup: same filters+page within 30 days returns `"free":true`**
  (no charge); `enrich_person` = 1 vendor credit/email; **`enrich_mobile:true` = 10 vendor credits** —
  gate to explicit phone asks. `account_information` = free pilot.
- **Do NOT use Prospeo for job-change detection/filters** — `person_job_change` has live schema drift; use FullEnrich for job-change workflows.
- **⚠️ WORK email only** (search/enrich return professional emails) — for candidate personal email use FullEnrich/LeadMagic/Wiza.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface — `lib/prospeo.py`
Import: `from lib.prospeo import Prospeo` → instantiate `Prospeo()` (reads key from env). Base: `https://api.prospeo.io`. Generic passthrough: `request(method, path, *, params, json)`.

- `account_information(payload: dict | None = None) -> dict` — POST /account-information — usage/renewal/credits (safe read-only pilot).
- `bulk_enrich_company(payload: dict) -> dict` — POST /bulk-enrich-company — up to 50 companies per call.
- `bulk_enrich_person(payload: dict) -> dict` — POST /bulk-enrich-person — up to 50 people per call.
- `domain_search(payload: dict) -> dict` — DEPRECATED → search_person/search_company. POST /domain-search.
- `email_finder(payload: dict) -> dict` — DEPRECATED → enrich_person. POST /email-finder (legacy work-email finder).
- `email_verifier(payload: dict) -> dict` — DEPRECATED. POST /email-verifier — verify an email address.
- `enrich_company(payload: dict) -> dict` — POST /enrich-company — company data enrichment.
- `enrich_person(data: dict, *, only_verified_email: bool | None = None, enrich_mobile: bool | None = None, only_verified_mobile: bool | None = None) -> dict` — POST /enrich-person — enrich one person (replaces email-finder/mobile-finder/social).
- `linkedin_email_finder(payload: dict) -> dict` — DEPRECATED → enrich_person. POST /linkedin-email-finder.
- `mobile_finder(payload: dict) -> dict` — DEPRECATED → enrich_person(enrich_mobile=True). POST /mobile-finder.
- `search_company(payload: dict) -> dict` — POST /search-company — query 30M+ companies.
- `search_person(payload: dict) -> dict` — POST /search-person — query 200M+ contacts with 30+ filters.
- `search_suggestions(payload: dict) -> dict` — POST /search-suggestions — canonical filter-value autocomplete before a search.
- `social_url_enrichment(payload: dict) -> dict` — DEPRECATED → enrich_person(data={'linkedin_url': ...}). POST /social-url-enrichment.

<!-- API-SURFACE:END -->
