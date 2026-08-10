---
name: hyreflow_native
description: "Hyreflow Native job scrapers — first-party, credit-metered, no subscription or API key. Scrape open roles from company career pages, LinkedIn, Indeed, and the German federal board (Arbeitsagentur). Use when the trigger is 'find open jobs at / for X' — e.g. all engineering roles a company is hiring, or recruiter openings in a city. Async: launch a scrape, then poll for results."
---

# hyreflow_native — Hyreflow Native (job & career-site scrapers)

HOW in `lib/hyreflow_native.py`.

## Kind: Hyreflow Native — read this first
- **First-party capability, no external vendor.** Runs on Hyreflow infrastructure.
- **No BYOK, no API key.** You never bring or hold a key — every call is metered in Hyreflow credits, so
  you don't need a separate scraper subscription. The provider-precedence waterfall does not apply.
- **Billing is pay-on-match.** Launching a scrape is **free**; you're charged **per job returned** when
  you fetch the results (an empty or still-running result costs nothing).

## The two-call (async) flow
Every scraper is asynchronous — a scrape takes a few minutes:
1. **Launch** with `scrape_*` (or its short alias) → returns `{request_id, status: "QUEUED"}`. Free.
2. **Poll** with `get_*` passing that `request_id` → `status` moves QUEUED → RUNNING → COMPLETED. When
   COMPLETED, `result` carries the scraped roles plus counts (see below). Poll every ~15–30s until
   COMPLETED or FAILED.

Billing is pay-on-match, **per unique job**: each job in a scrape is billed exactly once. Re-polling,
widening the `limit`, or overlapping/re-paged windows never double-charge — paging forward bills only the
newly-delivered jobs. (You don't have to page cleanly; the engine dedups per job.)

### Reading a COMPLETED result
`result` shape: `jobs` (the page of postings), `jobs_total` (everything the scrape found),
`jobs_returned` (how many are in this page — `len(jobs)`), `jobs_filtered_out` (matched but excluded by
your `filters`/`target_titles*` — deliberate, these are the rows your filters rejected), `limit`/`offset` (the window you got
back), `has_more` (more pages exist), and `warnings` (non-fatal issues with this poll, if any — a poll
always returns valid JSON, including on a transient upstream hiccup, so check `warnings` rather than
assuming silence means clean). The root object also carries `credits_consumed`, `credits_left`,
`started_at`, `finished_at`.

### Paging through `result.jobs`
`get_*` pollers take `limit`/`offset` (**default 10, max 50** — deliberately smaller than a single
career-page scrape can return, so one poll can't flood your context). A `limit` above 50 is **rejected,
not quietly trimmed**, so a paging loop can never silently skip the jobs a shortened page left behind —
if you want more than 50, take another page. To fetch **every** job rather than
just the first page, loop: call with `offset=0`, then keep incrementing `offset += limit` and re-polling
while `has_more` is `true`, concatenating `jobs` across calls. This costs nothing extra — billing dedups
per job, so paging over the same run never double-charges.

## Operations

| Scrape (free launch) | Alias | Poll for results |
|---|---|---|
| `scrape_career_pages` | `career_pages` | `get_career_pages` |
| `scrape_linkedin_jobs` | `linkedin_jobs` | `get_linkedin_jobs` |
| `scrape_indeed_jobs` | `indeed_jobs` | `get_indeed_jobs` |
| `scrape_arbeitsagentur_jobs` | `arbeitsagentur_jobs` | `get_arbeitsagentur_jobs` |

- **Career pages** — `scrape_career_pages(company_url, …)`: maps a company's site, follows its ATS
  (Greenhouse/Lever/Workday/Ashby), returns every posting. Narrow with `target_titles` (a list) **or**
  `target_titles_prompt` (a plain-English filter) — use one, not both.
  **Ask the user for the company's domain/website before launching** rather than guessing it from the
  company name — a guessed URL can map the wrong site. If they don't have it handy, offer to look it up
  (e.g. a web search tool) and confirm it with them before you call `scrape_career_pages`.
- **LinkedIn jobs** — `scrape_linkedin_jobs(titles_query=…, locations=…)` and/or `company_url=` (a
  LinkedIn company URL → that company's whole jobs page). `country` picks the regional site.
- **Indeed jobs** — `scrape_indeed_jobs(titles_query, locations, …)`. Both are required.
- **Arbeitsagentur** — `scrape_arbeitsagentur_jobs(title=…, location=…)` for the German federal job
  board (Bundesagentur für Arbeit). `radius` is in km. Need `title` and/or `location`.

## CLI
```bash
# 1. launch (free) — short alias
hyreflow tools execute linkedin_jobs --payload '{"titles_query":"recruiter","locations":["London"],"rows":50}'
#    → {"request_id":"...", "status":"QUEUED"}

# 2. poll until COMPLETED (charged per job in result.jobs)
hyreflow tools execute hyreflow_native_get_linkedin_jobs --payload '{"request_id":"<id>"}'
```

## When to reach for it
Open-roles / hiring intelligence: "what is this company hiring for", "find all RevOps openings in Berlin",
"pull recruiter jobs posted this week". Each returned job carries title, location, type, salary (when
available), the apply URL, and company fields — feed them straight into a sourcing or BD play.

## Gotcha
- **It's async — always poll.** The launch call returns a handle, not jobs. Don't treat the QUEUED
  response as the result; call the matching `get_*` until `status` is `COMPLETED`.
