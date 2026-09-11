---
name: hyreflow_native
description: "Hyreflow Native scrapers — first-party, credit-metered, no subscription or API key. Two families: JOB SCRAPES from company career pages, LinkedIn, Indeed and the German federal board (Arbeitsagentur) — use when the trigger is 'find open jobs at / for X'; and LINKEDIN POST FEEDS for a person or a company — use when the trigger is 'what has X been posting', or when you need launch / hiring / funding / exec-commentary / layoff signals straight from the source. Job scrapes are async (launch, then poll, charged per job); post feeds are one call, charged per request."
---

# hyreflow_native — Hyreflow Native (job scrapers & LinkedIn post feeds)

HOW in `lib/hyreflow_native.py`.

## Kind: Hyreflow Native — read this first
- **First-party capability, no external vendor.** Runs on Hyreflow infrastructure.
- **No BYOK, no API key.** You never bring or hold a key — every call is metered in Hyreflow credits, so
  you don't need a separate scraper subscription. The provider-precedence waterfall does not apply.
- **Two families, two billing models — check which one you're calling.**
  - **Job scrapes** (`scrape_*` / `get_*`): async, pay-on-match. Launching is **free**; charged **per job
    returned** on the retrieval poll (an empty or still-running result costs nothing).
  - **Post feeds** (`get_profile_posts` / `get_company_posts`): a single call, charged **per request** —
    one page of up to 50 posts, whatever the page carries, including a page that carries nothing.

## Job scrapes: the two-call (async) flow
Every job scraper is asynchronous — a scrape takes a few minutes:
1. **Launch** with `scrape_*` (or its short alias) → returns `{request_id, status: "QUEUED"}`. Free.
2. **Poll** with `get_*` passing that `request_id` → `status` moves QUEUED → RUNNING → COMPLETED. When
   COMPLETED, `result` carries the scraped roles plus counts (see below). Poll every **~10s** until
   COMPLETED or FAILED — re-polls dedup per job, so a tighter loop costs nothing and only shortens the dead
   wait; the terminal poll bills the same page whenever it lands.

Billing is pay-on-match, **per unique job**: each job in a scrape is billed exactly once. Re-polling,
widening the `limit`, or overlapping/re-paged windows never double-charge — paging forward bills only the
newly-delivered jobs. (You don't have to page cleanly; the engine dedups per job.)

- **⚠️ A poll that returns COMPLETED bills whatever `result.jobs` it carries — waiting is not free once
  the scrape is done.** `get_*` delivers a page on every poll (default `limit: 10`), so a wait loop that
  just re-polls **bills that page the moment the scrape finishes** — even if you only meant to check
  status. There is no zero-cost "status-only" poll shape (`limit` must be 1–50, so `limit: 0` is
  rejected). To avoid pre-billing before an approval gate: don't loop `get_*` eagerly once you suspect
  it's done; do one poll to confirm COMPLETED and treat the jobs it returns as **already billed and
  already yours** — don't discard them and re-fetch later expecting a fresh charge (dedup makes the
  re-fetch free, which also means you shouldn't tell the user the pilot was free just because that call
  reported 0).
- **Read `_meta.billed_jobs` and `_meta.already_billed` on every poll, not just `credits_charged`.**
  `credits_charged: 0` is ambiguous on its own — it means either "nothing delivered yet" (`billed_jobs: 0`,
  `already_billed: 0`) or "this poll's jobs were already billed on an earlier poll" (`already_billed > 0`).
  When summarizing a pilot's real cost at an approval gate, add up `billed_jobs` across *every* poll you
  made for that run (including earlier wait-loop polls), not just the last one — the last poll reporting 0
  does not mean the pilot was free.

### Running several scrapes in parallel
**Reach for this once the shape of the run is settled — after the pilot, past the approval gate above.**
Every run that reaches COMPLETED bills its page the moment you poll it, so a wide batch commits N pages of
spend at once; that's the same pre-billing the ⚠️ caution above is guarding against, just multiplied by the
size of the batch.

**Launch every scrape first, then poll them together.** A launch is free and returns immediately, so fire
all the `scrape_*` calls up front, collect their `request_id`s, and only then start polling. Wall-clock
becomes the slowest single scrape instead of the sum of all of them — never launch → poll to completion →
launch the next: that serial shape multiplies the wait by the number of scrapes.

- **Nothing serializes launches, and each run bills independently against its own `request_id`.** A batch
  of roughly **20** is a practical working size, not a system ceiling — result volume and the credit burst
  from polling that many runs to completion are what bound you, not any concurrency limit.
- **Poll round-robin on the ~10s cadence:** walk the outstanding `request_id`s once per cycle, dropping
  each one from the list as it reaches COMPLETED or FAILED.
- **One run failing doesn't touch the others** — a FAILED status is per `request_id`; relaunch just that
  one.
- **Twenty full pages at once is a lot of text, so keep `limit` deliberate and page only the runs still
  short of what you need.** That's also why a wide batch is riskier on spend than serial scraping: a batch
  can stop partway when a session spend cap or the workspace balance is reached mid-batch, since the engine
  enforces the cap after counting each page and withholds that result. Sum `_meta.billed_jobs` /
  `_meta.already_billed` across every poll (per the accounting rule above) to know a batch's real cost —
  that gets harder, not easier, with twenty runs in flight.
- **A single board-wide query rarely fills a large, country-wide target on its own.** Widen with a
  parallel batch of angles instead of one scrape at a time — the same titles across `linkedin_jobs` /
  `indeed_jobs` / `arbeitsagentur_jobs`, plus city- or region-scoped variants of the same query — launched
  together and polled as one batch.

```bash
# 1. launch several scrapes back-to-back (all free, all return immediately)
# `linkedin_jobs` / `indeed_jobs`: `country` selects the regional site and defaults to "United
# States", so a non-US sweep must set it. `arbeitsagentur_jobs` is Germany-only and takes no `country`.
hyreflow tools execute linkedin_jobs --payload '{"titles_query":"recruiter","locations":["Berlin"],"country":"Germany"}'
#    → {"request_id":"r1", "status":"QUEUED"}
hyreflow tools execute indeed_jobs --payload '{"titles_query":"recruiter","locations":["Munich"],"country":"Germany"}'
#    → {"request_id":"r2", "status":"QUEUED"}
hyreflow tools execute arbeitsagentur_jobs --payload '{"title":"recruiter","location":"Hamburg"}'
#    → {"request_id":"r3", "status":"QUEUED"}

# 2. poll the collected ids round-robin, ~10s per cycle, dropping each as it completes
hyreflow tools execute hyreflow_native_get_linkedin_jobs --payload '{"request_id":"r1"}'
hyreflow tools execute hyreflow_native_get_indeed_jobs --payload '{"request_id":"r2"}'
hyreflow tools execute hyreflow_native_get_arbeitsagentur_jobs --payload '{"request_id":"r3"}'
```

### Reading a COMPLETED result
`result` shape: `jobs` (the page of postings), `jobs_total` (everything the scrape found),
`jobs_returned` (how many are in this page — `len(jobs)`), `jobs_filtered_out` (matched but excluded by
your `filters`/`target_titles*` — deliberate, these are the rows your filters rejected), `limit`/`offset` (the window you got
back), `has_more` (more pages exist), and `warnings` (non-fatal issues with this poll, if any — a poll
always returns valid JSON, including on a transient upstream hiccup, so check `warnings` rather than
assuming silence means clean). The root object also carries `credits_consumed`, `credits_left`,
`started_at`, `finished_at`.

- **`rows` (launch) and `limit` (poll) are different knobs — size BOTH to the ask.** `rows` on
  `scrape_linkedin_jobs` / `scrape_indeed_jobs` bounds what the scraper collects upstream (LinkedIn
  defaults to the upstream default, Indeed to **25**); `limit` on the `get_*` poll bounds what a page hands
  back (**10**). They are independent: `rows: 15` with a default poll returns 10, and a default `rows` with
  `limit: 50` hands back up to 50. For "find me 15 roles", send `rows: 15` on the launch **and**
  `limit: 15` on the poll — then one poll delivers the ask and bills exactly it.
  `scrape_arbeitsagentur_jobs` and `scrape_career_pages` take **no `rows`** (`max_pages`/`page_size` and
  `max_pages` bound them instead), so there the poll's `limit` plus stopping at the ask is the only guard.
  A LinkedIn **direct fetch** (`linkedin_job_urls` / `linkedin_job_ids`) takes no `rows` either — its size
  is the number of distinct references you sent, so the poll's `limit` is the only knob. 100 references
  exceed one page: poll `offset: 0` then `offset: 50`, and expect up to 100 jobs ⇒ up to 5.0 credits.
- **`jobs_returned` is this page only — it says nothing about coverage.** With the default `limit: 10`, a
  first poll reporting 10 jobs is just the page size, not the find. Read `jobs_total` and `has_more`
  before concluding the scrape came up thin, and only widen with another scrape (or a parallel batch —
  above) when `jobs_total` really is short of the target, not when the first page merely looked short.

### Paging through `result.jobs`
`get_*` pollers take `limit`/`offset` (**default 10, max 50** — deliberately smaller than a single
career-page scrape can return, so one poll can't flood your context). A `limit` above 50 is **rejected,
not quietly trimmed**, so a paging loop can never silently skip the jobs a shortened page left behind —
if you want more than 50, take another page.

- **⚠️ Page to the ask, not to `has_more`.** Every page you advance to **bills the new jobs it
  delivers**. Dedup makes *re-polling a window you already fetched* free; it does **not** make the next
  window free. So `has_more: true` is not an instruction to keep going — it just means the scrape found
  more than you have. If the user asked for 15 roles, stop at 15: paging on to a run's full 50 bills all
  50, and "the tool told me there was more" is not a mandate the user agreed to pay for.
- To fetch **every** job deliberately (the user asked for exhaustive coverage, or a cost ceiling has been
  agreed), loop: call with `offset=0`, then keep incrementing `offset += limit` and re-polling while
  `has_more` is `true`, concatenating `jobs` across calls. Re-polling any window you already paid for
  stays free.

## Post feeds: one call, one page

`get_profile_posts` (alias `profile_posts`) reads a person's recent posts; `get_company_posts` (alias
`company_posts`) reads a company page's. Both take `username` — the handle out of the LinkedIn URL
(`linkedin.com/in/<username>`, `linkedin.com/company/<username>`), not the display name and not the whole
URL. Newest first, no polling: the call returns the posts.

- **One request = one page of up to 50 posts = one charge (0.2 credits).** The page size is fixed; you
  cannot buy a smaller page. `limit` trims how many posts land in your context (`limit: 10` when you only
  want the headlines) but does **not** reduce the charge — so never re-call with a bigger `limit` to "get
  the rest", because you already paid for those 50 and asking again is a second request. Take `limit: 50`
  and keep what you need.
- **Paging costs.** Walk further back by passing the `next_start` the last call handed you, while
  `has_more` is `true`. **Never advance by your own `limit`**: a request always fetches a full page of 50
  whatever `limit` trimmed off the end, so `start += limit` would re-request — and re-pay for — posts you
  are already holding. Unlike job polls, there is **no per-item dedup here**; every page, and every
  re-fetch of a page, is another request and another charge.
- **⚠️ An unreachable handle still costs the request.** A bad handle comes back as `success: false` with a
  `message` explaining why and no posts — and it is billed exactly like a full page, because the request
  was spent either way. Confirm the handle against the actual LinkedIn URL before calling; if you only have
  a company name or a person's name, resolve the URL first rather than guessing a handle.
- **Reading a page:** `posts` (the page), `posts_returned`, `start`/`limit` (the window), `has_more`,
  `next_start` (the offset to pass next, `null` on the last page), `success` and `message`. A **company** feed also reports `total` and `total_page` for the whole feed; a
  profile feed leaves both null, so use `has_more` there. Each post carries `text` (the full post),
  `postUrl`, `postedDate` + `postedDateTimestamp`, `totalReactionCount`, `commentsCount`, `repostsCount`,
  `contentType`, `author` (`name`, `headline`, `username`, `url` — empty on a company feed, since the
  company is the author) and `company_mentions` (names of companies tagged in the post).
- A full page of 50 is a large result. When you only need the recent signal, `limit: 10` keeps your context
  clear at the same price.

### What a post feed is, and isn't
Treat it as the account's **public posting history**, not a complete activity log:
- **Reposts appear with the original author**, not the account you asked for — check `author.username`
  against the handle you requested before attributing a quote to someone.
- **Comments and reactions are counts, not content.** You get `commentsCount` and `totalReactionCount`;
  you cannot read who commented or what they said.
- **A company feed's `author` is empty** — the company is the poster. Don't read that as missing data.
- **`postedAt` is relative and rounded** ("19h", "2w"). For anything you sort or filter on, use
  `postedDateTimestamp` (epoch ms) or `postedDate`.
- **The feed reflects what the account posted**, so an account that only reshares or never posts returns a
  thin feed at full price — that is a real answer about the account, not a failure.

## Operations

| Post feed | Alias | Reads |
|---|---|---|
| `get_profile_posts` | `profile_posts` | A person's recent posts |
| `get_company_posts` | `company_posts` | A company page's recent posts |

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
- **LinkedIn jobs** — three input modes, one per call. `scrape_linkedin_jobs(company_url=…)` (a LinkedIn
  company URL → that company's whole jobs page) on its own, **or** `titles_query=` together with
  `locations=`, **or** `linkedin_job_urls=` and/or `linkedin_job_ids=` — a **direct fetch** of exactly
  those postings (1–100 per field, pairable; an id given both ways is fetched once). Reach for the direct
  fetch whenever you **already hold** the posting — a URL the user pasted, the `job_url` off an earlier
  scrape, a link from a jobs page — instead of guessing a title/location search that may not surface it.
  It runs no search, so no other search input goes with it (no `country`, no `rows`), and it always
  returns job detail. `len(result.jobs)` can be smaller than the references you sent: a dead or
  unfetchable posting costs nothing, and `jobs_filtered_out` is always 0 (there are no filters). In
  search mode `country` only picks the regional site — it never substitutes for `locations`.
- **Indeed jobs** — `scrape_indeed_jobs(titles_query, locations, …)`. Both are required.
- **Arbeitsagentur** — `scrape_arbeitsagentur_jobs(title=…, location=…)` for the German federal job
  board (Bundesagentur für Arbeit). `radius` is in km. Need `title` and/or `location`.

## CLI
```bash
# post feed — one call, one charge (0.2 cr), newest first
hyreflow tools execute profile_posts --payload '{"username":"acme-dana-reed","limit":10}'
hyreflow tools execute company_posts --payload '{"username":"acme","start":50}'
```

```bash
# The user asked for 15 roles, so BOTH knobs say 15: `rows` bounds the scrape, `limit` bounds the page.
# 1. launch (free) — short alias
hyreflow tools execute linkedin_jobs --payload '{"titles_query":"recruiter","locations":["London"],"rows":15}'
#    → {"request_id":"...", "status":"QUEUED"}

# 2. poll until COMPLETED (charged per job in result.jobs — 15 here, not the default page of 10)
hyreflow tools execute hyreflow_native_get_linkedin_jobs --payload '{"request_id":"<id>","limit":15}'
```

```bash
# Direct fetch — you already hold the postings, so no search runs and no other search input is sent.
# Two references → at most 2 jobs → at most 0.1 credits on the poll.
hyreflow tools execute linkedin_jobs --payload '{"linkedin_job_urls":["https://www.linkedin.com/jobs/view/4123456789"],"linkedin_job_ids":["4000000001"]}'
hyreflow tools execute hyreflow_native_get_linkedin_jobs --payload '{"request_id":"<id>","limit":2}'
```

## When to reach for it
**Job scrapes** — open-roles / hiring intelligence: "what is this company hiring for", "find all RevOps
openings in Berlin", "pull recruiter jobs posted this week". This is the **default source for open-roles /
hiring-signal work** — first-party, no vendor account or vendor credits, and the lowest metered per-role
cost among the sources that are always available without a vendor key.
**Germany is the one geo with a board of its own — add it as a leg, don't substitute it.**
A Germany-scoped query starts with `arbeitsagentur_jobs` (the German federal board): German employers
post there who never list on the global boards, so a DE run that skips it misses companies, not just
postings. Run it alongside `linkedin_jobs` / `indeed_jobs` and dedup on the apply URL. Every other
geo runs on the global boards plus `career_pages` — there is no national board to reach for.
Each returned job carries title, location,
type, salary (when available), the apply URL, and company fields — feed them straight into a sourcing or BD
play.

**Post feeds** — timing and voice: "what has this company been posting", "any hiring posts from their
talent lead", "did they announce a raise", "what are they saying about the launch". Post text plus
engagement counts is what turns a cold opener into a specific one, and a hiring post is a live signal a job
board hasn't indexed yet. Also the right call when someone asks for a person's or company's LinkedIn
activity directly.

## Anti-patterns
- **Don't judge coverage from `jobs_returned`.** It's this page only (default `limit: 10`), not the find —
  a first poll showing 10 jobs can sit under a scrape that found hundreds. Check `jobs_total` and
  `has_more` before deciding the scrape came up thin, and widen with another scrape only when `jobs_total`
  itself is short of the target.
- **A genuinely thin board needs a different BOARD, not a different title.** Once `jobs_total` really is
  short, that's a coverage gap in the board — add the geo's own (DE ⇒ `arbeitsagentur_jobs`) and dedup on
  the apply URL, rather than re-querying the same board for a synonym of the same role.
- **Don't re-call a feed with a bigger `limit` to "get the rest".** The first call already fetched and
  charged for all 50; a second call is a second charge for posts you were handed. Take `limit: 50` when you
  might want more than a handful.
- **Don't guess a handle.** `acme` and `acme-inc` are different accounts and a wrong one is billed like a
  real answer. Resolve the LinkedIn URL first if you only have a company or person name.
- **Don't page a feed "to be thorough".** Every 50 posts is another request and another charge, with no
  dedup between them. Page only while you still need older posts, and stop when `has_more` is false.
- **Don't compute the next offset yourself.** Pass back `next_start`; deriving it from `limit` re-fetches
  posts you already paid for.
- **Don't poll a post feed.** There is no job to wait on; a repeat call is just a repeat charge.
- **Don't reach for a post feed to find open roles.** That's a job scrape — cheaper per role and
  structured for it. Post feeds are for what an account is *saying*, including a hiring post a job board
  hasn't indexed yet.

## Gotcha
- **A job scrape is async — always poll.** The launch call returns a handle, not jobs. Don't treat the
  QUEUED response as the result; call the matching `get_*` until `status` is `COMPLETED`.
- **A post feed is not.** There is no `scrape_*` half to launch and no `request_id` to poll — calling
  `get_profile_posts` / `get_company_posts` IS the fetch, and it charges on that one call.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute hyreflow_native <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get hyreflow_native <method>` returns the live contract + cost). Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `get_arbeitsagentur_jobs(request_id: str, *, limit: int = 10, offset: int = 0) -> dict` — GET /v1/scrape-arbeitsagentur-jobs/async/{request_id} — poll a German hiring-signal scrape for open roles on Germany's Bundesagentur für Arbeit board (paginated result.jobs).
- `get_career_pages(request_id: str, *, limit: int = 10, offset: int = 0) -> dict` — GET /v1/scrape-career-pages/async/{request_id} — poll a career-page hiring-signal scrape for open roles (paginated result.jobs).
- `get_company_posts(username: str, start: int = 0, limit: int = 50) -> dict` — GET /v1/linkedin-company-posts — a company page's recent LinkedIn posts, newest first.
- `get_indeed_jobs(request_id: str, *, limit: int = 10, offset: int = 0) -> dict` — GET /v1/scrape-indeed-jobs/async/{request_id} — poll an Indeed hiring-signal scrape for open roles (paginated result.jobs).
- `get_linkedin_jobs(request_id: str, *, limit: int = 10, offset: int = 0) -> dict` — GET /v1/scrape-linkedin-jobs/async/{request_id} — poll a LinkedIn hiring-signal scrape for open roles (paginated result.jobs).
- `get_profile_posts(username: str, start: int = 0, limit: int = 50) -> dict` — GET /v1/linkedin-profile-posts — a person's recent LinkedIn posts, newest first.
- `get_run(run_id: str) -> dict` — GET /v1/runs/{run_id} — generic job poller ({run_id, status, result} when COMPLETED).
- `scrape_arbeitsagentur_jobs(title: str | None = None, location: str | None = None, radius: int = 25, job_type: str | None = None, max_pages: int = 3, page_size: int = 25, include_details: bool = True, solve_captcha: bool = False) -> dict` — POST /v1/scrape-arbeitsagentur-jobs/async — start a German hiring-signal scrape of open roles on Germany's Bundesagentur für Arbeit board. Returns {request_id, status}.
- `scrape_career_pages(company_url: str, company_name: str | None = None, max_pages: int = 10, target_titles: list | None = None, target_titles_prompt: str | None = None, target_locations: list | None = None, filters: dict | None = None, known_career_page_url: str | None = None, known_career_page_urls: list | None = None) -> dict` — POST /v1/scrape-career-pages/async — start a hiring-signal scrape of a named company's own career site/ATS for open roles. Returns {request_id, status}.
- `scrape_indeed_jobs(titles_query: Any, locations: list, country: str = 'United States', rows: int = 25, start: int = 0, radius: int | None = None, job_types: list | None = None, max_age_days: int | None = None, include_job_details: bool = True, include_company_details: bool = False) -> dict` — POST /v1/scrape-indeed-jobs/async — start a hiring-signal scrape of Indeed open roles by title + location across companies. Returns {request_id, status}.
- `scrape_linkedin_jobs(titles_query: Any = None, company_url: str | None = None, locations: list | None = None, country: str | None = None, rows: int | None = None, distance: str | None = None, hours: int | None = None, job_types: list | None = None, work_types: list | None = None, experience_levels: list | None = None, excluded_companies: list | None = None, excluded_titles: list | None = None, excluded_industries: list | None = None, include_company_details: bool | None = None, include_job_details: bool | None = None, linkedin_job_urls: list | None = None, linkedin_job_ids: list | None = None) -> dict` — POST /v1/scrape-linkedin-jobs/async — start a hiring-signal scrape of LinkedIn open roles by title/location, for one company, or for specific job postings. Returns {request_id, status}.
- `search_posts(keyword: str, date_posted: str | None = None, sort_by: str = 'date_posted', page: int = 1, limit: int = 50, author_title: str | None = None, from_members: list | None = None, content_type: str | None = None) -> dict` — POST /v1/linkedin-post-search — keyword search across public LinkedIn posts, newest first, scoped to a date window.

<!-- API-SURFACE:END -->
