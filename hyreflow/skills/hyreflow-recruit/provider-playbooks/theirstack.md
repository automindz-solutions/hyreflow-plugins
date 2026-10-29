# TheirStack Agent Guidance

## Decision Framework

**Use TheirStack when:**

- You need tech-stack-driven company discovery (TheirStack's core strength)
- You need job posting data filtered by technology or keyword slug across many companies, as a hiring intent signal
- You need to enrich a known company's tech stack

**Do not use TheirStack when:**

- You need to filter by MX/email provider such as Microsoft 365, Office 365, Google Workspace, or Gmail. `theirstack_search_companies` has no `company_email_provider` filter. Use `prospeo_search_company` with `company_email_provider` when the MX provider value is supported, or use `theirstack_company_technographics` and post-filter returned `email_tech.mx_provider` evidence.
- You need person/contact enrichment — TheirStack has no people data. Route to `aiark`, `prospeo`, or `lusha` instead.
- The ask is open roles / who-is-hiring with no tech-stack filter — even when it is narrowed by recency, excluded titles, "posted by a recruiting agency" or what the description must mention; the natives take those as launch filters or a post-filter on the job and company details they return. The Hyreflow native job scrapes cover that at a fraction of the credit cost and need no vendor credits (`linkedin_jobs`, `indeed_jobs`, `career_pages`, and `arbeitsagentur_jobs` + `stepstone_jobs` for the German market); see [`hyreflow_native.md`](hyreflow_native.md). Route to TheirStack when the query needs keyword-slug/tech-stack filters, technographics or buying intent.

## Operation Sequence

1. **Validate keyword slugs first (free):** Use `theirstack_catalog_keywords` to look up the correct keyword slug (e.g., `react`, `salesforce`, `hubspot`) before running a paid company or job search.

2. **Company discovery:** Use `theirstack_search_companies` with `company_technology_slug_or` or `company_technology_slug_and`. For precision, use `_and`. For broad reach, use `_or`.

3. **Hiring signals:** Use `theirstack_search_jobs` to find companies actively hiring for specific roles or technologies. Always provide `posted_at_max_age_days` or a company filter — the API requires at least one.

4. **Tech stack enrichment:** Use `theirstack_company_technographics` for a single known company — provide `company_domain` when possible (most reliable identifier).

5. **Budget before large batch runs:** count-before-pay off the search response, price it with
   `hyreflow tools get theirstack <method>`, and check `hyreflow billing balance` for headroom.
   `theirstack_credit_balance` reads the TheirStack account's own credit meter — it's callable only when
   the workspace has connected its own TheirStack key, and even then it's a different pool from the
   workspace's Hyreflow balance.

## Key Filters

- **Keyword slugs** use kebab-case (e.g., `react`, `node-js`, `salesforce`). Use `theirstack_catalog_keywords` to find the exact slug first.
- **Field names differ by endpoint:** `theirstack_search_companies` and company-level filters on `theirstack_search_jobs` use `company_technology_slug_*`; job text filters on `theirstack_search_jobs` use `job_technology_slug_*`; `theirstack_company_technographics` uses `keyword_slug_or`.
- **No email-provider filter:** do not invent `company_email_provider`, `email_provider`, `mx_provider`, or similar fields for TheirStack company search.
- **Country codes** are ISO 2-letter (e.g., `US`, `GB`, `DE`).
- **Funding stages** (`funding_stage_or`): common ones are `pre_seed`, `seed`, `series_a` … `series_j`, `growth_equity_vc`,
  `private_equity`, `post_ipo_equity`, `debt_financing`, `undisclosed`. There is no `growth` or `ipo`; an unlisted value is not rejected, it silently matches nothing.
- **Job seniority** (`job_seniority_or`): only `c_level`, `staff`, `senior`, `junior`, `mid_level`. There is no
  `manager`, `director` or `vp`; filter those by `job_title_or` instead.

## Cost Awareness

- Company search: per company returned, in Hyreflow credits. Use `limit: 10` for exploration.
- Job search: per job returned, in Hyreflow credits. Safe to use with `limit: 25`.
- Technographics: per company lookup (regardless of result count), in Hyreflow credits.
- Catalog keywords: free.
- Check `hyreflow tools get theirstack <method>` for the live rate before scaling up `limit`, and
  `hyreflow billing balance` for the workspace's remaining Hyreflow credits.

## Common Mistakes

- Forgetting to provide a time filter OR company filter on job search → API returns error
- Using display names for keywords instead of slugs → no results
- Reusing `keyword_slug_or` from technographics in `theirstack_search_companies` → use `company_technology_slug_or` instead
- Using Prospeo-style MX filters such as `company_email_provider` in `theirstack_search_companies` → TheirStack does not support email-provider filtering
- Setting `limit` too high on company search → expensive
- Long exclusion lists (dozens of `industry_id_not` / `job_title_not` values) → searches slow enough to time out. Narrow with the positive filters first (`job_title_or`, location, `posted_at_max_age_days`), keep the few `*_not` values that remove the most jobs and post-filter only the long tail (every job you drop afterwards is still paid for), and don't set `include_total_results: true` on a heavy search (it is off by default and slows the response down a lot)

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute theirstack <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get theirstack <method>` returns the live contract + cost). Base: `https://api.theirstack.com`. Only the methods listed below are callable.

- `catalog_industries(*, industry: str | None = None, page: int = 0, limit: int = 25) -> Any` — GET /v0/catalog/industries — industry codes (+job/company counts). Free. LinkedIn Industry Codes V2.
- `catalog_keywords(**params) -> Any` — GET /v0/catalog/keywords — technology/keyword slugs (free; use slugs in *_technology_slug_or filters).
- `catalog_locations(**params) -> Any` — GET /v0/catalog/locations — location reference data (free).
- `company_buying_intents(*, company_domain: str | None = None, company_name: str | None = None, company_linkedin_url: str | None = None, **extra) -> Any` — POST /v1/companies/buying_intents — buying-intent topics detected for a company (3 TheirStack credits, vendor-side).
- `company_technographics(*, company_domain: str | None = None, company_name: str | None = None, company_linkedin_url: str | None = None, **extra) -> Any` — POST /v1/companies/technologies — technologies a company uses (3 TheirStack credits, vendor-side).
- `create_company_list(payload: dict) -> Any` — POST /v0/company_lists — create a company list.
- `credit_balance() -> Any` — GET /v0/billing/credit-balance — remaining credits on the caller's own TheirStack account; requires the workspace's own key.
- `get_company_list(list_id: str | int) -> Any` — GET /v0/company_lists/{id}.
- `list_company_lists(**params) -> Any` — GET /v0/company_lists — all company lists for the team.
- `search_companies(filters: dict | None = None, *, page: int = 0, limit: int = 25, blur_company_data: bool | None = None, **extra) -> Any` — POST /v1/companies/search — company search. **3 THEIRSTACK credits per company returned** (vendor-side; hyreflow's price is this method's `cost` block).
- `search_jobs(filters: dict | None = None, *, page: int = 0, limit: int = 25, **extra) -> Any` — POST /v1/jobs/search — hiring-signal job search. **1 THEIRSTACK credit per job returned** (vendor-side; the hyreflow price you budget with is this method's `cost` block).

<!-- API-SURFACE:END -->
