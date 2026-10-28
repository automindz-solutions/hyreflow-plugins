---
name: hyreflow_native
description: "Hyreflow Native tools — first-party, credit-metered, no subscription or API key. JOB SCRAPES (`scrape_*`/`get_*`) from company career pages, LinkedIn, Indeed and the two German boards (Arbeitsagentur, the federal board; StepStone, the commercial one) — async launch→poll, charged per job — for 'find open jobs at / for X'. POST FEEDS (`get_profile_posts`/`get_company_posts`) for a person or company — one call, 50 posts a page, charged per request — for 'what has X been posting' and launch / hiring / funding / exec-commentary / layoff signals. POST SEARCH (`search_posts`) — keyword search over public LinkedIn posts, past week by default, `author_title` to narrow to recruiters, 10 posts a page — for 'who is posting about X'. POST REACTIONS (`get_post_reactions`) — the people who reacted to a post, 10 reactors a page, per request — for 'who engaged with this post'. PROFILE LOOKUP (`get_linkedin_profile`) — one person's LinkedIn profile and dated work history by URL, no contact detail, charged per request; the second step of the `linkedin_profile` waterfall. POSTCODE RADIUS (`places_within_radius`, free) — turns 'within N miles of <postcode>' into the town list a people search `locations` filter takes. REPOST SCAN (`repost_scan`, free; its PredictLeads history pages bill at their own rate) — a company's reposted, long-open and monthly-relisted roles from its job-opening history, for 'is this company struggling to fill X'. EMAIL VERIFICATION (`verify_emails`/`get_verified_emails`) — inbox-level, async, charged per address submitted at launch, returns ONLY the addresses safe to send to; the default for every verify/validate ask, and what `email_enrichment` already runs on every email it finds."
---

# hyreflow_native — Hyreflow Native tools

HOW in `lib/hyreflow_native.py`.

## Kind: Hyreflow Native — read this first
- **First-party capability, no external vendor.** Runs on Hyreflow infrastructure.
- **No BYOK, no API key.** You never bring or hold a key — every call is metered in Hyreflow credits, so
  you don't need a separate scraper subscription. One tool sits in a waterfall: profile lookup (second in
  `linkedin_profile`); the rest run on their own.
- **Eight capabilities, five billing shapes — check which one you're calling.**
  - **Job scrapes** (`scrape_*` / `get_*`): async, pay-on-match. Launching is **free**; charged **per job
    returned** on the retrieval poll (an empty or still-running result costs nothing).
  - **Post feeds** (`get_profile_posts` / `get_company_posts`): a single call, charged **per request** —
    one page of up to 50 posts, whatever the page carries, including a page that carries nothing.
  - **Post search** (`search_posts`): same per-request contract, but **a page is 10 posts**, not 50.
  - **Post reactions** (`get_post_reactions`): same per-request contract — a page is 10 reactors.
  - **Profile lookup** (`get_linkedin_profile`): a single call, charged **per request** — one profile,
    including a URL that resolves to no profile.
  - **Postcode radius** (`places_within_radius`): free — no credits.
  - **Email verification** (`verify_emails` → `get_verified_emails`): async like a job scrape, but charged
    **per address submitted, at launch** (polling is free), and only the addresses safe to send to come back.
  - **Repost scan** (`repost_scan`): the scan is free; each PredictLeads history page it pulls is charged
    at the PredictLeads `job_openings` rate (one page per domain, a page holds 1,000 listings — up to three
    pages when a domain's history runs past 1,000 listings), and costs nothing on the workspace's own
    PredictLeads key. `--dry-run` quotes one page per domain, and a scan above the confirmation threshold
    asks first like any paid call.

## Job scrapes: the two-call (async) flow
Every job scraper is asynchronous — a scrape takes a few minutes:
1. **Launch** with `scrape_*` (or its short alias) → returns `{request_id, status: "QUEUED"}`. Free.
2. **Poll** with `get_*` passing that `request_id` → `status` moves QUEUED → RUNNING → COMPLETED. When
   COMPLETED, `result` carries the scraped roles plus counts (see below). A LinkedIn run can also end
   **PARTIAL**: finished, but some postings failed to load — treat it as done (see below). Poll every
   **~10s** until COMPLETED, PARTIAL or FAILED — re-polls dedup per job, so a tighter loop costs nothing
   and only shortens the dead wait; the terminal poll bills the same page whenever it lands.

Billing is pay-on-match, **per unique job**: each job in a scrape is billed exactly once. Re-polling,
widening the `limit`, or overlapping/re-paged windows never double-charge — paging forward bills only the
newly-delivered jobs. (You don't have to page cleanly; the engine dedups per job.)

- **⚠️ A poll that returns COMPLETED (or PARTIAL) bills whatever `result.jobs` it carries — waiting is
  not free once the scrape is done.** `get_*` delivers a page on every poll (default `limit: 10`), so a wait loop that
  just re-polls **bills that page the moment the scrape finishes** — even if you only meant to check
  status. There is no zero-cost "status-only" poll shape (`limit` must be 1–50, so `limit: 0` is
  rejected). To avoid pre-billing before an approval gate: don't loop `get_*` eagerly once you suspect
  it's done; do one poll to confirm COMPLETED (or PARTIAL) and treat the jobs it returns as **already billed and
  already yours** — don't discard them and re-fetch later expecting a fresh charge (dedup makes the
  re-fetch free, which also means you shouldn't tell the user the pilot was free just because that call
  reported 0).
- **Read `_meta.billed_jobs` and `_meta.already_billed` on every poll, not just `credits_charged`.**
  `credits_charged: 0` is ambiguous on its own — it means either "nothing delivered yet" (`billed_jobs: 0`,
  `already_billed: 0`) or "this poll's jobs were already billed on an earlier poll" (`already_billed > 0`).
  When summarizing a pilot's real cost at an approval gate, add up `credits_charged` across *every* poll
  you made for that run (including earlier wait-loop polls), not just the last one — the last poll
  reporting 0 does not mean the pilot was free. Report that sum, not `billed_jobs` x the per-job rate:
  a job with a surcharge (an Arbeitsagentur job returned with recruiter details) costs more than the rate,
  so the multiplication under-reports it. `billed_jobs` is the job COUNT.

### Running several scrapes in parallel
**Reach for this once the shape of the run is settled — after the pilot, past the approval gate above.**
Every run that reaches COMPLETED or PARTIAL bills its page the moment you poll it, so a wide batch commits N pages of
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
  each one from the list as it reaches COMPLETED, PARTIAL or FAILED.
- **One run failing doesn't touch the others** — a FAILED status is per `request_id`; relaunch just that
  one.
- **Twenty full pages at once is a lot of text, so keep `limit` deliberate and page only the runs still
  short of what you need.** That's also why a wide batch is riskier on spend than serial scraping: a batch
  can stop partway when a session spend cap or the workspace balance is reached mid-batch, since the engine
  enforces the cap after counting each page and withholds that result. Sum `_meta.credits_charged`
  across every poll (per the accounting rule above) to know a batch's real cost —
  that gets harder, not easier, with twenty runs in flight.
- **A single board-wide query rarely fills a large, country-wide target on its own.** Widen with a
  parallel batch of angles instead of one scrape at a time — the same titles across `linkedin_jobs` /
  `indeed_jobs` / `arbeitsagentur_jobs` / `stepstone_jobs`, plus city- or region-scoped variants of the same query — launched
  together and polled as one batch.

```bash
# 1. launch several scrapes back-to-back (all free, all return immediately)
# `linkedin_jobs` / `indeed_jobs`: `country` selects the regional site (upstream's own default is the
# US site when omitted; `indeed_jobs` additionally defaults the param itself to "United States"), so a
# non-US sweep must set it. `arbeitsagentur_jobs` and `stepstone_jobs` are Germany-only and take no `country`.
hyreflow tools execute linkedin_jobs --payload '{"titles_query":"recruiter","locations":["Berlin"],"country":"Germany"}'
#    → {"request_id":"r1", "status":"QUEUED"}
hyreflow tools execute indeed_jobs --payload '{"titles_query":"recruiter","locations":["Munich"],"country":"Germany"}'
#    → {"request_id":"r2", "status":"QUEUED"}
hyreflow tools execute arbeitsagentur_jobs --payload '{"title":"recruiter","location":"Hamburg"}'
#    → {"request_id":"r3", "status":"QUEUED"}
hyreflow tools execute stepstone_jobs --payload '{"title":"recruiter","location":"Hamburg"}'
#    → {"request_id":"r4", "status":"QUEUED"}

# 2. poll the collected ids round-robin, ~10s per cycle, dropping each as it completes
hyreflow tools execute hyreflow_native_get_linkedin_jobs --payload '{"request_id":"r1"}'
hyreflow tools execute hyreflow_native_get_indeed_jobs --payload '{"request_id":"r2"}'
hyreflow tools execute hyreflow_native_get_arbeitsagentur_jobs --payload '{"request_id":"r3"}'
hyreflow tools execute hyreflow_native_get_stepstone_jobs --payload '{"request_id":"r4"}'
```

### Reading a COMPLETED result
`result` shape: `jobs` (the page of postings), `jobs_total` (everything the scrape found),
`jobs_returned` (how many are in this page — `len(jobs)`), `jobs_filtered_out` on sources that report it
(matched but excluded by your `filters`/`target_titles*`; LinkedIn and Indeed don't report it, their filters
run upstream), `limit`/`offset` (the window you got
back), `has_more` (more pages exist), and `warnings` (non-fatal issues with this poll, if any — a poll
always returns valid JSON, including on a transient upstream hiccup, so check `warnings` rather than
assuming silence means clean). The root object also carries `credits_consumed`, `credits_left`,
`started_at`, `finished_at`.
**StepStone names the run total `total_found`** (not `jobs_total`), adds `pages_scraped`, and has no
`jobs_filtered_out` — read `total_found` wherever this page says `jobs_total`.

- **`rows` (launch) and `limit` (poll) are different knobs — size BOTH to the ask.** `rows` on
  `scrape_linkedin_jobs` / `scrape_indeed_jobs` bounds what the scraper collects upstream (LinkedIn
  defaults to the upstream default, Indeed to **25**); `limit` on the `get_*` poll bounds what a page hands
  back (**10**). They are independent: `rows: 15` with a default poll returns 10, and a default `rows` with
  `limit: 50` hands back up to 50. For "find me 15 roles", send `rows: 15` on the launch **and**
  `limit: 15` on the poll — then one poll delivers the ask and bills exactly it. `limit` maxes at 50 on
  every poller, so a LinkedIn `rows: 100` run takes two polls: `offset` 0, then 50. Indeed returns only
  its first page (about 15 jobs) whatever `rows` says, so one poll covers an Indeed run.
  `scrape_arbeitsagentur_jobs` and `scrape_career_pages` take **no `rows`** (`max_pages`/`page_size` and
  `max_pages` bound them instead), so there the poll's `limit` plus stopping at the ask is the only guard.
  `scrape_stepstone_jobs` takes `rows` but only in **whole pages of 25** (25/50/75/100, default 25 —
  anything else is rejected): for "find me 15 roles" send the default `rows: 25` and `limit: 15` on the
  poll. StepStone has no result offset, so page a deeper search by stepping `start_page` by `rows / 25`
  across runs (`rows: 50` → `start_page` 1, 3, 5 …) and stop at the first run whose `result.total_found` is 0 (or once you have enough). Don't stop on a
  merely short run: a full StepStone page can come back a listing or two short, and an empty run is free.
  A LinkedIn **direct fetch** (`linkedin_job_urls` / `linkedin_job_ids`) takes no `rows` either — its size
  is the number of distinct references you sent, so the poll's `limit` is the only knob. 100 references
  exceed one page: poll `offset: 0` then `offset: 50`, and expect up to 100 jobs ⇒ up to 5.0 credits.
- **`jobs_returned` is this page only — it says nothing about coverage.** With the default `limit: 10`, a
  first poll reporting 10 jobs is just the page size, not the find. Read `jobs_total` and `has_more`
  before concluding the scrape came up thin, and only widen with another scrape (or a parallel batch —
  above) when `jobs_total` really is short of the target, not when the first page merely looked short.

- **Lean output on `get_linkedin_jobs` / `get_indeed_jobs`:** `fields` (list) keeps only those job fields —
  names differ by source: LinkedIn `["title","company_name","job_url"]`, Indeed
  `["job_title","company_name","job_url"]` — and `max_description_chars` (e.g. 300) truncates descriptions.
  Both are applied after the response, never sent upstream, and don't change billing (jobs are counted, not
  bytes). A name that is not a job field of that source (and on no job of the page) is refused before the
  page is billed, and the error lists the valid names: fix the name and re-poll. A valid name a job doesn't
  carry (e.g. `salary`, or a company field on a run without company details) is just absent from that job,
  so the same `fields` works on every page. Only top-level `description` / `job_description` are truncated, so drop
  company detail with `fields` too when context is tight.
- **PARTIAL (LinkedIn) is terminal, not "still running".** The run finished, but `result.failed_scrapes`
  postings could not be loaded. `result.jobs` holds what was scraped and bills
  like COMPLETED (failed postings are not in it, so they cost nothing). Stop polling on PARTIAL: a loop that
  waits only for COMPLETED never ends. When `result.errors` lists the failed postings by URL or id (at most
  100 per argument), recover them once per run by relaunching only those as `linkedin_job_urls` /
  `linkedin_job_ids` on their own (a direct fetch takes no other input); `_meta.warnings` says which applies.
  When it doesn't, tell the user the list is incomplete. Never re-run the whole search: a new run is a
  new `request_id`, so every job already delivered would bill again.
- **A page carrying `result.warnings` is not the last page.** A LinkedIn walk stops early when 3 result
  pages in a row had no job passing your filters, and says so in `warnings`; a short run with that
  warning means "maybe more" (relaunch more broadly or with fewer filters), not "nothing left". Only a
  short run with no `warnings` is the end.
- **Upstream scrape problems reach `_meta.warnings`:** on the first page (`offset` 0) of a finished
  LinkedIn / Indeed poll, `failed_scrapes`, `errors` and `partial` appear there as `job_scrape_partial`, and
  the first few upstream `warnings` entries as `job_scrape_warning`. Later pages don't repeat them; the raw
  fields stay in `result` on every page.

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
- **Comments are counts, not content.** You get `commentsCount` and `totalReactionCount`; you cannot
  read who commented or what they said. Who *reacted* IS readable — `get_post_reactions` on the post's
  `postUrl` (below).
- **A company feed's `author` is empty** — the company is the poster. Don't read that as missing data.
- **`postedAt` is relative and rounded** ("19h", "2w"). For anything you sort or filter on, use
  `postedDateTimestamp` (epoch ms) or `postedDate`.
- **The feed reflects what the account posted**, so an account that only reshares or never posts returns a
  thin feed at full price — that is a real answer about the account, not a failure.

## Post search: one keyword, one page of 10

`search_posts` (alias `post_search`) finds public LinkedIn posts by **what they say**, not who said them —
the tool for a hiring signal you can't attach to a handle yet: recruiting-agency staff announcing a
search, a hiring manager posting "we're hiring", a founder mentioning a new office. One call, posts
inline, no polling. **Read this section before the first call — the shape below is the one that works;
don't probe for it, every probe is a paid request.**

```json
{"keyword": "we are hiring", "author_title": "Recruiter"}
```
That is the whole default payload for the agency-staff cut: past week, newest first, page 1. Everything
else is optional.

| Argument | Default | Notes |
|---|---|---|
| `keyword` | required | text the post must contain; a multi-word phrase is fine (`"we are hiring"`) — send it verbatim, no quoting |
| `date_posted` | `past-week` | `past-24h` · `past-week` · `past-month` · `any` (aliases `24h`/`today`, `week`/`7d`, `month`/`30d`, `all` accepted) |
| `sort_by` | `date_posted` | `date_posted` (newest first) or `relevance` — exactly these two tokens |
| `author_title` | none | headline filter: `"Recruiter"`, `"Talent Acquisition"`, `"Head of Talent"` |
| `from_members` | none | list of profile handles to restrict to |
| `content_type` | none | upstream post type filter; leave empty unless you know the token |
| `page` | `1` | 1-based; advance with the `next_page` the previous call returned |
| `limit` | `10` | trims what lands in context; a page is 10 anyway, so it is a context knob, never a cost knob |

- **One request = one page of up to 10 posts = one charge (0.2 credits).** A search page is a fifth of a
  feed page, so budget 5 requests (1.0 cr) for ~50 hits. The charge lands whether the page is full,
  thin, or empty — a keyword nobody used this week costs the same as a full page.
- **Newest-first and the window.** With the default `sort_by: date_posted` the stream is newest-first and
  the window is applied to that stream: `total` is the whole unwindowed match set (hundreds for
  `"hiring"`), and the walk **ends on the first page that reaches past the window** — `has_more: false`,
  `next_page: null`. That is the signal to stop, not `total`. With `sort_by: relevance` the window
  filters upstream and `total` counts only posts inside it.
- **Narrow before you page.** `"hiring"` alone matches everything on LinkedIn; `"hiring"` +
  `author_title: "Recruiter"` is the agency-staff signal in one request. Use the phrase the target actually
  writes (`"we are hiring"`, `"now hiring"`, `"looking for a recruiter"`) rather than paging a broad one.
- **Reading a page:** `posts` (same record as a feed post: `text`, `postUrl`, `postedDate` +
  `postedDateTimestamp`, reaction/comment/repost counts, `contentType`, `author` {`name`, `headline`,
  `username`, `url`}, `company_mentions`), `posts_returned`, `total`, `page`, `page_size` (10), `limit`,
  `date_posted`, `sort_by`, `has_more`, `next_page`, `success`, `message`. `author.username` is the handle
  to hand `profile_posts` if that person's history matters.
- **An empty page whose `message` says "No matching posts returned (the search source reported no
  result twice)" is a transient upstream miss, not a real zero.** The same call succeeds a moment later;
  the engine already retried once for you. Re-run the identical call once — do not change the payload,
  the payload was not the problem. It is still one charged request, like any other page.

```bash
# recruiting-agency staff announcing a search this week — one call, one charge (0.2 cr), 10 posts max
hyreflow tools execute search_posts --payload '{"keyword":"we are hiring","author_title":"Recruiter"}'

# next page (only while has_more is true), and a wider window ranked by relevance
hyreflow tools execute search_posts --payload '{"keyword":"we are hiring","author_title":"Recruiter","page":2}'
hyreflow tools execute search_posts --payload '{"keyword":"talent acquisition partner","date_posted":"past-month","sort_by":"relevance"}'
```

## Post reactions: who engaged with a post

`get_post_reactions` (alias `post_reactions`) reads the people who reacted to one LinkedIn post — the
engagement list a feed row's `totalReactionCount` only counts. Pass the post's `postUrl` (or any
`linkedin.com/posts/...` link). One call, reactors inline, no polling.

- **One request = one page of up to 10 reactors = one charge (0.2 credits).** `total`/`total_pages` report
  the whole reaction set, so a heavily-reacted post is a paged read — budget a request per 10 reactors
  and stop when `next_page` is `null`. `limit` trims what lands in context, never what a request costs.
- **`reaction_type` narrows to one reaction kind** — `LIKE` (the common case), `EMPATHY`, `PRAISE`,
  `INTEREST`, `FUNNY` or `APPRECIATION`. Omit it for all reactions.
- **Each reactor carries `fullName`, `headline`, `profileUrl`, `urn`, `profileType` and the
  `reactionType` they left** — `headline` is the quick ICP check, and `profileUrl` is the handle to hand
  `profile_posts` or a profile enrich.
- **An unreachable post still costs the request** — same contract as a feed: `success: false` with a
  `message`, billed like a full page. An empty page whose `message` says "No reactions returned (the
  source reported the request failed twice)" is a transient miss, not a real zero — re-run the same call.

```bash
# who reacted to a post — one call, one charge (0.2 cr), 10 reactors max
hyreflow tools execute post_reactions --payload '{"url":"https://www.linkedin.com/posts/acme-dana-reed_we-are-hiring-740001"}'
# next page, and a single reaction kind
hyreflow tools execute post_reactions --payload '{"url":"https://www.linkedin.com/posts/acme-dana-reed_we-are-hiring-740001","page":2,"reaction_type":"LIKE"}'
```

## Profile lookup: one URL, one profile
`get_linkedin_profile` reads one person's LinkedIn profile from its URL (`linkedin.com/in/<handle>`; a bare
handle works too, and a share link's `?utm_…` tail is dropped). It is the **second step of the
`linkedin_profile` waterfall**, so for work history on a list of people run
`hyreflow tools execute linkedin_profile` / `POST /enrich/linkedin_profile` and let the waterfall pick —
call this directly only when you want this one source's full record for a single person.

Returns `{success, profile, message}`. `profile` carries `full_name`, `headline`, `about`, `location`,
`country`, `is_open_to_work`, `is_hiring`, `experience[]` (newest first: `company`, `title`, `start`/`end`
as `YYYY-MM`, `is_current`, plus `location`, `employment_type`, `description`, `company_linkedin_url`,
`company_industry`, `company_size`), `education[]` (`school`, `degree`, `field_of_study`, `start`, `end`),
`skills`, `certifications` and `languages`. **No email or phone** — it is safe on candidate rows. A URL
that resolves to no profile comes back `success: false`, `profile: null`, and is still one charged
request, so check the URL before spending it.

**When the source is down, the call answers from the waterfall.** If the lookup itself is unavailable
(its allowance is used up, it is refusing calls, it is not set up, or it timed out), the call runs the
`linkedin_profile` waterfall for that one URL without this source and returns its answer in the same
`{success, profile, message}` shape, plus `source` (the provider that answered, e.g. `aiark`) and
`fallback: {from, reason, charged}`. It is charged what the waterfall charges: the answering provider's
price when a profile is found, plus any source on the way that bills a miss (`fallback.charged`). A
"no profile found" answer never falls back: it is an answer. Fields only this source carries (`username`, `urn`, `first_name`/`last_name`, `country`, `photo_url`, `is_open_to_work`,
`is_hiring`, `languages`, a role's `location`/`employment_type`/company page/industry/size, and a school's
`field_of_study` and dates) come back empty from another source. The fallback stays within what you
approved, or, if you approved nothing, within the amount Hyreflow would otherwise ask you to confirm,
counting every fallback in the request (lookups that answered from this source don't count): past that it
does not run and you get the error instead. A source that is only busy (too many calls at once) does not
fall back: it returns "temporarily unavailable" with no `linkedin_profile` line, so wait and retry it.

**If the call still returns an error (424) that says to use `linkedin_profile` instead, the source
itself is down** (its allowance used up, or refusing calls, not set up or timing out), so further calls are
likely to fail the same way: switch the remaining rows to the `linkedin_profile` waterfall, which reaches
the other sources.

An error without that line is about the one URL you sent: fix it or skip that row, and keep using this
source. The exception is "temporarily unavailable": the source is busy, so retry the same URL after a short
wait instead of skipping it.

```bash
# one person's full profile — one call, one charge (0.2 cr)
hyreflow tools execute hyreflow_native get_linkedin_profile --payload '{"linkedin_url":"https://www.linkedin.com/in/acme-dana-reed"}'
```

## Postcode or city radius: towns within N miles (free)

People databases match a person's location by **exact town name** and have **no radius filter** — no
provider in the `people_search` waterfall can search "within 3 miles of SW1A 1AA" or "within 20 km of
Marburg" directly. `places_within_radius` (alias `postcode_radius`) bridges that: it geocodes the centre and
returns every city, town, village and suburb inside the radius, nearest first, as a ready-made `locations`
list.

- The centre — pass exactly one:
  - `postcode` — a **full** postcode/ZIP (`"SW1A 1AA"`, `"94103"`, `"10115"`). A bare UK outcode (`"SW1A"`)
    is not found; ask for the full postcode or use a street postcode in the target area.
  - `place` — a city, town or village name (`"Marburg"`, `"Bielefeld"`). It matches the settlement only,
    so `"New York"` is the city, not the state.
- `radius` + `unit` — `mi` (default) or `km`, up to 25 km (about 15 mi). Wider than that, search the metro
  labels instead (Prospeo's ZONE suggestion covers a metro in one value). `country` — ISO-2 (`"gb"`, `"de"`,
  `"us"`), set it whenever you know it; a town name like `"Newport"` exists in several countries.
- `limit` — the nearest N places (default 50, max 200). Every location adds a resolve step to
  `people_search`, so keep the default unless the user wants a wider net.
- Returns `{center, radius_km, places:[{name, type, distance_km}], locations, total_places, truncated}`;
  `locations` leads with the centre's own town. A big radius can take up to ~30 s. Free — no credits.

```bash
hyreflow tools execute postcode_radius --payload '{"postcode":"SW1A 1AA","radius":3,"country":"gb"}'
hyreflow tools execute postcode_radius --payload '{"place":"Marburg","radius":20,"unit":"km","country":"de"}'
# → locations: ["City of Westminster","Victoria","Belgravia","Mayfair","London", …]
# then pass them (plus the metro label people actually list, e.g. "London") to people_search
hyreflow tools execute people_search --payload '{"titles":["Recruiter"],"locations":["London","City of Westminster","Victoria","Belgravia","Mayfair"]}'
```

It narrows to **towns**, not doorsteps: a profile says "London", never a postcode, so a match means "lives
in a town inside the circle". Tell the user that, and keep the metro label in the list — most people list
the metro, not their suburb, so a suburb-only list under-matches.

## Email verification: only safe-to-send addresses come back

**The default for every "verify / validate / clean these emails" ask** — 0.05 cr per address submitted,
first-party, no vendor key. Route to `enrichley`, `leadmagic` or `icypeas` only when the user names one.

- **`email_enrichment` already verifies.** Every work email the waterfall finds is checked this way
  before it reaches the row, and one that isn't safe to send to is dropped (the chain then tries the next
  provider). If the verifier can't answer for an address, or finds its domain is catch-all, Enrichley
  checks it instead. A row carrying `"email_verifier": "enrichley"` (the user named Enrichley) is checked
  by Enrichley alone. Don't
  re-verify enrichment output — call `verify_emails` for addresses from anywhere else.
- `verify_emails(emails)` — 1 to 50,000 addresses, each checked down to the mailbox. Returns
  `{request_id, status: "QUEUED", submitted, duplicates_removed, rejected}`. Poll
  `get_verified_emails(request_id)` every ~10 s (a few hundred addresses finish in minutes; tens of
  thousands take longer) until `status` is `COMPLETED` or `FAILED`.
- **Reading a COMPLETED poll:** `result.emails` holds **only** the addresses safe to send to
  (`is_safe_to_send: true`). Every other address — invalid, catch-all, role account (`info@`), disposable,
  full or disabled inbox, spam trap, or no verdict — is withheld and never returned as a result;
  `result.withheld` counts them. Tell the user how many were withheld. Two kinds are named, bare, in case
  the user wants a second opinion on them: `result.catch_all` (the domain accepts any mailbox, so this one
  can't be confirmed) and `result.unknown` (no verdict). Page with `limit`
  (1–1000, default 100) and `offset += limit` while `has_more`.
- **Cost:** 0.05 cr per address submitted, charged at launch whatever the verdict (duplicates and
  malformed addresses the launch drops are free). Polling is free. Quote it at the approval gate (2,000
  addresses = 100 cr). The launch is refused (402) unless the balance covers every address.

```bash
# launch (charged per address), then poll (free)
hyreflow tools execute verify_emails --payload '{"emails":["jane@acme.example.com","joe@acme.example.com"]}'
#    → {"request_id":"ev_...", "status":"QUEUED", "submitted":2, ...}
hyreflow tools execute hyreflow_native_get_verified_emails --payload '{"request_id":"ev_..."}'
#    → COMPLETED: result.emails [{email: "jane@acme.example.com", is_safe_to_send: true, ...}], result.withheld 1
```

## Repost scan: hard-to-fill roles in a company's history

`repost_scan` reads a company's PredictLeads job-opening history for the lookback and returns only the roles
that show a hard-to-fill signal, strongest first, each with its listings as evidence (ids, first/last-seen
dates, URLs). It applies the same rules as Step 5 of
[`../recipes/repost-signal-to-bd.md`](../recipes/repost-signal-to-bd.md):

- `repost` — a listing first seen in the last `fresh_days` days (default 2; 30 for a backfill), after an
  earlier listing of the same role at the same site ran 21+ days and stopped. `cycles` counts the earlier
  listings that ran that long.
- `long-open` — the role has been live 90+ days, through relists that picked up within 3 days.
- `evergreen` — three or more back-to-back relists about a month apart, the latest live.

Two listings are the same role when the titles match once seniority words and gender tags are dropped
(PredictLeads' English `normalized_title` carries a language switch) and they sit in the same town.
Apprenticeship, student and intern listings never count. An ATS switch or a same-site mass relist
continues the old listing rather than reading as a repost (`not_signals.ats_migration`).

- `domain` — the company's domain. `related_domains` — its parent or subsidiary domains (up to 4), read
  as one history; the result's `parent_company_domain` names a parent PredictLeads knows of. A group parent
  usually owns many unrelated companies, so add it only when the role could be posted under it.
- `titles` (`["Account Executive"]`) or `onet_codes` (`["41-3091.00"]`) narrow the scan to one role; with
  neither, every role is checked. The per-listing O*NET code is unreliable, so prefer `titles`.
- `lookback_months` (default 12, at most 24); `limit` (default 20, at most 100) caps `signals`, and
  `signals_total` has the full count.
- `needs_review` — pairs the titles can't settle: a rename or a new qualifier at the same site where
  joining the two would raise a signal (`would_be`), or country-only listings of a role the company posts
  at several branches. Fetch the two descriptions (`predictleads get_job_opening`) and decide.
- `stale: true` — the company's newest listing was last seen 14+ days ago, so nothing counts as live and
  long-open and evergreen aren't reported. `warnings` says so, and also when a history ran past 3,000
  listings and was cut off, or PredictLeads' crawl may be blocked. With any warning, a role missing
  from `signals` is not a "no".

```bash
hyreflow tools execute hyreflow_native repost_scan --payload '{"domain":"acme.example.com","titles":["Account Executive"],"fresh_days":30}'
# → signals: [{signal:"repost", title, site, cycles, open_since, listings:[…earlier…, {role:"new", …}]}],
#   needs_review, not_signals, stale, warnings, history_pages
```

## Operations

| Post feed / search | Alias | Reads |
|---|---|---|
| `get_profile_posts` | `profile_posts` | A person's recent posts |
| `get_company_posts` | `company_posts` | A company page's recent posts |
| `search_posts` | `post_search` | Public posts matching a keyword, past week by default |
| `get_post_reactions` | `post_reactions` | The people who reacted to a post, 10 a page |
| `get_linkedin_profile` | — | One person's profile and dated work history, by LinkedIn URL |
| `places_within_radius` | `postcode_radius` | Towns within a radius of a postcode or city, as a `locations` list (free) |

| Scrape (free launch) | Alias | Poll for results |
|---|---|---|
| `scrape_career_pages` | `career_pages` | `get_career_pages` |
| `scrape_linkedin_jobs` | `linkedin_jobs` | `get_linkedin_jobs` |
| `scrape_indeed_jobs` | `indeed_jobs` | `get_indeed_jobs` |
| `scrape_arbeitsagentur_jobs` | `arbeitsagentur_jobs` | `get_arbeitsagentur_jobs` |
| `scrape_stepstone_jobs` | `stepstone_jobs` | `get_stepstone_jobs` |
| `verify_emails` | `verify_emails` | `get_verified_emails` |

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
  unfetchable posting costs nothing. In
  search mode `country` only picks the regional site — it never substitutes for `locations`.
  **Clinical / healthcare searches:** a title keyword like "physician" or "doctor" also matches pharma,
  CRO and med-tech roles, which crowd out hospital postings. Search the local-language titles too
  (e.g. Hungarian "orvos", "szakorvos", "rezidens" alongside the English), and narrow to the sector
  you want with `included_industries` (e.g. `["Hospitals and Health Care", "Medical Practices"]`), with
  `excluded_companies` for recurring CRO names.
- **Indeed jobs** — `scrape_indeed_jobs(titles_query, locations, …)`. Both are required. `country` picks
  Indeed's regional site. Before a sweep in a new market, run one small scrape (`rows: 5`) and check
  that `result.search_urls` is on that country's Indeed site and the jobs' locations are in-country. A
  country Indeed has no site for comes back with no jobs and a `warnings` entry saying so (nothing is
  billed); use `linkedin_jobs` for that market instead.
- **Seniority and industry filters (LinkedIn + Indeed)** — a title keyword alone pulls in the wrong
  employers: "CEO" matches charities, councils, hospitals and staffing firms. Set `included_industries`
  to the sector you want and `experience_levels` to the level (`internship`, `entry level`, `associate`,
  `mid-senior level`, `director`, `executive`) on either board, instead of listing every unwanted
  industry in `excluded_industries`. Both boards also take `excluded_titles` / `excluded_companies`.
  - Seniority and industry are labels an LLM classifier assigns from each job's detail page (each job
    shows them as `seniority` / `industry`), so they can drift between runs.
  - Industry terms are LinkedIn industry names, matched case-insensitively as a substring
    (`"renewable"` keeps "Renewable Energy Power Generation"). Use the real names.
  - A job the classifier could not label is **kept**, with a `result.warnings` entry. Check those rows
    yourself.
  - Industry filters need the job detail page, so they cannot go with `include_job_details: false`.
    On a LinkedIn `company_url` scrape any seniority or industry filter turns detail fetches on and an
    omitted `rows` defaults to 50, so set `rows` to the ask.
  - Filtered-out jobs are never returned and never billed. Billing stays per returned job.
  - On LinkedIn a filtered run reads more search pages to fill `rows`, so it takes longer. Fewer jobs
    than `rows` does **not** mean the board ran out: a warning says the run stopped early and lists the
    labels it dropped most. If those look wrong, widen the filter rather than paging on.
  - Indeed serves only its first page (about 15 jobs), so an Indeed filter thins those ~15 and cannot
    page deeper to fill `rows`. For more, run narrower searches (more titles or locations).
- **Arbeitsagentur** — `scrape_arbeitsagentur_jobs(title=…, location=…)` for the German federal job
  board (Bundesagentur für Arbeit). `radius` is in km. Need `title` and/or `location`. Recruiter details
  only appear with `include_recruiter_details: true` (slower); the poll bills
  **+0.1 credits** per job with recruiter details, up to 0.15 credits per job
  including the per-job rate. A job returned without recruiter details
  bills the per-job rate only. Re-polling never re-bills the surcharge.
- **StepStone** — `scrape_stepstone_jobs(title=…, location=…)` for Germany's largest commercial job
  board. `title` is **required** (there is no location-only search); omit `location` for all of Germany,
  `radius` is in km. Optional filters: `posted_within_days` (`1` or `7` only), `work_type`
  (`full-time`/`part-time`), `work_from_home` (`partial`/`only`), `job_language` (`de`/`en`),
  `application_method` (`company-website`/`quick-apply`), and `discipline` (StepStone's job family —
  e.g. `it`, `hr`, `sales`, `engineering`; an unknown value is rejected rather than silently matching
  nothing). Salary is login-gated on StepStone, so `salary_*` is always null — don't promise it.
  `include_details: false` is faster but returns the search-card teaser as the description and **no
  `posted_at`** — keep the default when recency matters.

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

# 2. poll until COMPLETED, PARTIAL or FAILED (charged per job in result.jobs — 15 here, not the default page of 10)
hyreflow tools execute hyreflow_native_get_linkedin_jobs --payload '{"request_id":"<id>","limit":15}'
```

```bash
# Direct fetch — you already hold the postings, so no search runs and no other search input is sent.
# Two references → at most 2 jobs → at most 0.1 credits on the poll.
hyreflow tools execute linkedin_jobs --payload '{"linkedin_job_urls":["https://www.linkedin.com/jobs/view/4123456789"],"linkedin_job_ids":["4000000001"]}'
hyreflow tools execute hyreflow_native_get_linkedin_jobs --payload '{"request_id":"<id>","limit":2}'
```

```bash
# Executive search — CEOs at renewable-energy employers in the UK, not charities, councils or agencies.
hyreflow tools execute linkedin_jobs --payload '{"titles_query":"CEO renewable","locations":["United Kingdom"],"rows":25,"experience_levels":["executive"],"included_industries":["Renewable Energy Power Generation","Solar Electric Power Generation","Wind Electric Power Generation","Utilities","Environmental Services"]}'
# The same filters on Indeed (no seniority or industry data there, so every job is classified). Indeed
# returns about 15 jobs before filtering, so `rows: 25` is a ceiling, not a target.
hyreflow tools execute indeed_jobs --payload '{"titles_query":"chief executive renewable","locations":["London"],"country":"United Kingdom","rows":25,"experience_levels":["executive","director"],"included_industries":["Renewable Energy Power Generation","Utilities"]}'
```

## When to reach for it
**Job scrapes** — open-roles / hiring intelligence: "what is this company hiring for", "find all RevOps
openings in Berlin", "pull recruiter jobs posted this week". This is the **default source for open-roles /
hiring-signal work** — first-party, no vendor account or vendor credits, and the lowest metered per-role
cost among the sources that are always available without a vendor key.
**Germany is the one geo with a board of its own — add it as a leg, don't substitute it.**
A Germany-scoped query starts with `arbeitsagentur_jobs` (the German federal board): German employers
post there who never list on the global boards, so a DE run that skips it misses companies, not just
postings. `stepstone_jobs` (Germany's largest commercial board) is the second German leg — the federal
board carries the public listings and recruiter contacts, StepStone the commercial ones, and German
clients generally want both. Run them alongside `linkedin_jobs` / `indeed_jobs` and dedup on the apply URL. Every other
geo runs on the global boards plus `career_pages` — there is no national board to reach for.
**A narrowed ask is still a native ask.** Recency, exclusions, who posted it and what the description
says are not reasons to switch to theirstack: `linkedin_jobs` takes `hours` (posted within the last N
hours — 21 days is `504`; `indeed_jobs` takes `max_age_days`), `excluded_titles` ("no recruiter jobs"),
`experience_levels` and `included_industries` / `excluded_industries` (both boards); for "posted by a
recruiting agency" or "the description names the recruiter", launch with `include_company_details` + `include_job_details` and filter the returned postings on their
company and description fields yourself. theirstack is for tech-stack / keyword-slug filters,
technographics and buying intent — no other filter moves a hiring query off the natives (the user naming
theirstack, or the native legs coming back short, still does). The user's language
doesn't change the route either; write `titles_query` in the language of the board you're searching.
Each returned job carries title, location,
type, salary (when available), the apply URL, and company fields — feed them straight into a sourcing or BD
play.

**Post feeds** — timing and voice: "what has this company been posting", "any hiring posts from their
talent lead", "did they announce a raise", "what are they saying about the launch". Post text plus
engagement counts is what turns a cold opener into a specific one, and a hiring post is a live signal a job
board hasn't indexed yet. Also the right call when someone asks for a person's or company's LinkedIn
activity directly.

**Post search** — the hiring signal without a handle: "who is posting about hiring recruiters this
week", "agency staff announcing a search", "anyone mentioning a new Berlin office". Search finds the
people; a feed then reads one of them.

**Repost scan** — "which of these companies keep reposting the role", "is Acme struggling to fill its
AE role": one call per company after discovery and the company gate in the repost recipe. It replaces
reading the job-opening history in the chat; read the history by hand only for `needs_review` pairs.

**Profile lookup** — who someone is and where they've worked: "pull her work history", "is he open to
work", "what's this person's current title". For more than one person, run the `linkedin_profile`
waterfall rather than this method directly.

**Email verification** — every "verify / validate / clean these emails" ask, and the verify step before
any sequence or campaign send for addresses that didn't come out of `email_enrichment` (those are
already verified). Only safe-to-send addresses come back.

## Anti-patterns
- **Don't judge coverage from `jobs_returned`.** It's this page only (default `limit: 10`), not the find —
  a first poll showing 10 jobs can sit under a scrape that found hundreds. Check `jobs_total` and
  `has_more` before deciding the scrape came up thin, and widen with another scrape only when `jobs_total`
  itself is short of the target.
- **A genuinely thin board needs a different BOARD, not a different title.** Once `jobs_total` really is
  short, that's a coverage gap in the board — add the geo's own (DE ⇒ `arbeitsagentur_jobs`, then `stepstone_jobs`) and dedup on
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
- **Don't probe `search_posts` for a working payload.** The default payload works; every variant you try
  is 0.2 cr. Change ONE argument at a time if you must, and never vary the sort and the window together.
- **Don't expect 50 posts from a search.** A search page is 10; `limit: 50` still returns 10 and still
  costs one request. Page on `next_page` for more, and stop when it is `null`. A reactions page is 10
  too — same rule for `get_post_reactions`.
- **Don't reach for a post feed to find open roles.** That's a job scrape — cheaper per role and
  structured for it. Post feeds are for what an account is *saying*, including a hiring post a job board
  hasn't indexed yet.

## Gotcha
- **A job scrape is async — always poll.** The launch call returns a handle, not jobs. Don't treat the
  QUEUED response as the result; call the matching `get_*` until `status` is `COMPLETED` (or `PARTIAL` / `FAILED`).
- **A post feed is not.** There is no `scrape_*` half to launch and no `request_id` to poll — calling
  `get_profile_posts` / `get_company_posts` IS the fetch, and it charges on that one call.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute hyreflow_native <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get hyreflow_native <method>` returns the live contract + cost). Only the methods listed below are callable.

- `get_arbeitsagentur_jobs(request_id: str, *, limit: int = 10, offset: int = 0) -> dict` — GET /v1/scrape-arbeitsagentur-jobs/async/{request_id} — poll a German hiring-signal scrape for open roles on Germany's Bundesagentur für Arbeit board (paginated result.jobs).
- `get_career_pages(request_id: str, *, limit: int = 10, offset: int = 0) -> dict` — GET /v1/scrape-career-pages/async/{request_id} — poll a career-page hiring-signal scrape for open roles (paginated result.jobs).
- `get_company_posts(username: str, start: int = 0, limit: int = 50) -> dict` — GET /v1/linkedin-company-posts — a company page's recent LinkedIn posts, newest first.
- `get_indeed_jobs(request_id: str, *, limit: int = 10, offset: int = 0, fields: list | None = None, max_description_chars: int | None = None) -> dict` — GET /v1/scrape-indeed-jobs/async/{request_id} — poll an Indeed hiring-signal scrape for open roles (paginated result.jobs).
- `get_linkedin_jobs(request_id: str, *, limit: int = 10, offset: int = 0, fields: list | None = None, max_description_chars: int | None = None) -> dict` — GET /v1/scrape-linkedin-jobs/async/{request_id} — poll a LinkedIn hiring-signal scrape for open roles (paginated result.jobs).
- `get_linkedin_profile(linkedin_url: str) -> dict` — GET /v1/linkedin-profile — one person's LinkedIn profile by URL: headline, location, about, dated work history (newest first), education, skills.
- `get_post_reactions(url: str, page: int = 1, reaction_type: str | None = None, limit: int = 10) -> dict` — POST /v1/linkedin-post-reactions — the people who reacted to a LinkedIn post.
- `get_profile_posts(username: str, start: int = 0, limit: int = 50) -> dict` — GET /v1/linkedin-profile-posts — a person's recent LinkedIn posts, newest first.
- `get_run(run_id: str) -> dict` — GET /v1/runs/{run_id} — generic poller ({run_id, status, result} when COMPLETED) for runs you own that are not native scrapes. Scrape jobs are polled with their typed poller (get_X for scrape_X), never this.
- `get_stepstone_jobs(request_id: str, *, limit: int = 10, offset: int = 0) -> dict` — GET /v1/scrape-stepstone-jobs/async/{request_id} — poll a German hiring-signal scrape for open roles on StepStone (paginated result.jobs).
- `get_verified_emails(request_id: str, *, limit: int = 100, offset: int = 0) -> dict` — GET /v1/verify-emails/async/{request_id} — poll a bulk email verification (paginated result.emails: only the addresses safe to send to).
- `places_within_radius(postcode: str | None = None, *, radius: float, unit: str = 'mi', country: str | None = None, limit: int = 50, place: str | None = None) -> dict` — GET /v1/places-within-radius — towns, villages and suburbs within a radius of a postcode or a city, ready to pass as a people search `locations` list.
- `repost_scan(domain: str, *, related_domains: list | None = None, titles: list | None = None, onet_codes: list | None = None, fresh_days: int = 2, lookback_months: int = 12, limit: int = 20) -> dict` — GET /v1/repost-scan — find a company's hard-to-fill roles in its job-opening history: reposts, roles open 90+ days, and roles relisted every month.
- `scrape_arbeitsagentur_jobs(title: str | None = None, location: str | None = None, radius: int = 25, job_type: str | None = None, max_pages: int = 3, page_size: int = 25, include_details: bool = True, include_recruiter_details: bool = False) -> dict` — POST /v1/scrape-arbeitsagentur-jobs/async — start a German hiring-signal scrape of open roles on Germany's Bundesagentur für Arbeit board. Returns {request_id, status}.
- `scrape_career_pages(company_url: str, company_name: str | None = None, max_pages: int = 10, target_titles: list | None = None, target_titles_prompt: str | None = None, target_locations: list | None = None, filters: dict | None = None, known_career_page_url: str | None = None, known_career_page_urls: list | None = None) -> dict` — POST /v1/scrape-career-pages/async — start a hiring-signal scrape of a named company's own career site/ATS for open roles. Returns {request_id, status}.
- `scrape_indeed_jobs(titles_query: Any, locations: list, country: str = 'United States', rows: int = 25, start: int = 0, radius: int | None = None, job_types: list | None = None, max_age_days: int | None = None, include_job_details: bool = True, include_company_details: bool = False, experience_levels: list | None = None, included_industries: list | None = None, excluded_industries: list | None = None, excluded_titles: list | None = None, excluded_companies: list | None = None) -> dict` — POST /v1/scrape-indeed-jobs/async — start a hiring-signal scrape of Indeed open roles by title + location across companies. Returns {request_id, status}.
- `scrape_linkedin_jobs(titles_query: Any = None, company_url: str | None = None, locations: list | None = None, country: str | None = None, rows: int | None = None, distance: str | None = None, hours: int | None = None, job_types: list | None = None, work_types: list | None = None, experience_levels: list | None = None, excluded_companies: list | None = None, excluded_titles: list | None = None, excluded_industries: list | None = None, include_company_details: bool | None = None, include_job_details: bool | None = None, linkedin_job_urls: list | None = None, linkedin_job_ids: list | None = None, included_industries: list | None = None) -> dict` — POST /v1/scrape-linkedin-jobs/async — start a hiring-signal scrape of LinkedIn open roles by title/location, for one company, or for specific job postings. Returns {request_id, status}.
- `scrape_stepstone_jobs(title: str, location: str | None = None, radius: int | None = None, rows: int = 25, start_page: int = 1, work_type: str | None = None, posted_within_days: int | None = None, work_from_home: str | None = None, job_language: str | None = None, application_method: str | None = None, discipline: str | None = None, include_details: bool = True) -> dict` — POST /v1/scrape-stepstone-jobs/async — start a German hiring-signal scrape of open roles on StepStone, Germany's largest commercial job board. Returns {request_id, status}.
- `search_people(filters: dict, page: int = 0, size: int = 25) -> dict` — POST /v1/people-search — filtered search over a licensed contact database; rows carry work emails where known.
- `search_posts(keyword: str, date_posted: str | None = None, sort_by: str = 'date_posted', page: int = 1, limit: int = 10, author_title: str | None = None, from_members: list | None = None, content_type: str | None = None) -> dict` — POST /v1/linkedin-post-search — keyword search across public LinkedIn posts, newest first, scoped to a date window.
- `verify_emails(emails: list) -> dict` — POST /v1/verify-emails/async — start an inbox-level verification of 1 to 50,000 email addresses. Returns {request_id, status}.

<!-- API-SURFACE:END -->
