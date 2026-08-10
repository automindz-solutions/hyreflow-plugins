# TheirStack Agent Guidance

## Decision Framework

**Use TheirStack when:**

- You need tech-stack-driven company discovery (TheirStack's core strength)
- You need job posting data as a hiring intent signal
- You need to enrich a known company's tech stack

**Do not use TheirStack when:**

- You need to filter by MX/email provider such as Microsoft 365, Office 365, Google Workspace, or Gmail. `theirstack_search_companies` has no `company_email_provider` filter. Use `prospeo_search_company` with `company_email_provider` when the MX provider value is supported, or use `theirstack_company_technographics` and post-filter returned `email_tech.mx_provider` evidence.
- You need person/contact enrichment — TheirStack has no people data. Route to `aiark`, `prospeo`, or `lusha` instead.

## Operation Sequence

1. **Validate keyword slugs first (free):** Use `theirstack_catalog_keywords` to look up the correct keyword slug (e.g., `react`, `salesforce`, `hubspot`) before running a paid company or job search.

2. **Company discovery:** Use `theirstack_search_companies` with `company_keyword_slug_or` or `company_keyword_slug_and`. For precision, use `_and`. For broad reach, use `_or`.

3. **Hiring signals:** Use `theirstack_search_jobs` to find companies actively hiring for specific roles or technologies. Always provide `posted_at_max_age_days` or a company filter — the API requires at least one.

4. **Tech stack enrichment:** Use `theirstack_company_technographics` for a single known company — provide `company_domain` when possible (most reliable identifier).

5. **Check credits:** Use `theirstack_credit_balance` before large batch runs.

## Key Filters

- **Keyword slugs** use kebab-case (e.g., `react`, `node-js`, `salesforce`). Use `theirstack_catalog_keywords` to find the exact slug first.
- **Field names differ by endpoint:** `theirstack_search_companies` and company-level filters on `theirstack_search_jobs` use `company_keyword_slug_*`; job text filters on `theirstack_search_jobs` use `job_keyword_slug_*`; `theirstack_company_technographics` uses `keyword_slug_or`.
- **No email-provider filter:** do not invent `company_email_provider`, `email_provider`, `mx_provider`, or similar fields for TheirStack company search.
- **Country codes** are ISO 2-letter (e.g., `US`, `GB`, `DE`).
- **Funding stages:** `seed`, `series_a`, `series_b`, `series_c`, `growth`, `ipo`.
- **Job seniority:** `senior`, `junior`, `manager`, `director`, `vp`, `c_level`.

## Cost Awareness

- Company search: per company returned. Use `limit: 10` for exploration.
- Job search: per job returned. Safe to use with `limit: 25`.
- Technographics: per company lookup (regardless of result count).
- Catalog keywords and credit balance: free.
- Check `hyreflow tools get theirstack <method>` for the live rate before scaling up `limit`.

## Common Mistakes

- Forgetting to provide a time filter OR company filter on job search → API returns error
- Using display names for keywords instead of slugs → no results
- Reusing `keyword_slug_or` from technographics in `theirstack_search_companies` → use `company_keyword_slug_or` instead
- Using Prospeo-style MX filters such as `company_email_provider` in `theirstack_search_companies` → TheirStack does not support email-provider filtering
- Setting `limit` too high on company search → expensive
