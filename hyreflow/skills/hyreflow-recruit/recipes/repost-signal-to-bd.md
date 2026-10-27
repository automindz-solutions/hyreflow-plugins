# Recipe — Repost signal → BD on hard-to-fill roles

**Use when:** the trigger is *"find companies that are reposting roles"* or a **hard-to-fill hiring
signal**. The recipe reports three signals, strongest first:
- **repost** — the same role goes live again after the earlier listing ran for weeks and closed. A role
  reposted after running roughly **6 weeks or longer**, or reposted over several cycles, is the strongest
  form.
- **long-open** — one listing has stayed live for 90 days or more without being filled.
- **evergreen** — the same role is relisted on a regular monthly rhythm: the company hires for it all the
  time, so it keeps needing people.

All three target companies with a **standing need for the role** (a BD opening on the hiring side), not
companies that are simply hiring for something new — a freshly-posted role with no prior listing isn't in
scope.

> **What's next + why:** this is the **signal → BD** branch of the funnel (hard-to-fill trigger). See
> [`../recruiter-craft.md`](../recruiter-craft.md) §B for the branch and the work-email channel rule.

## Where this runs (Model A)
The O*NET resolution, the company gate and the scoring are **reasoning done by the host agent** — free,
no hosted AI model call. The repost detection runs on the server (`hyreflow_native repost_scan`, Steps 4
and 5), free apart from the history pages it pulls. Credits are spent on the PredictLeads discovery and
history pulls (Steps 2 and 4) and on enriching the *survivors'* contacts downstream.

## Inputs
- Role title (or an O*NET code already in hand) + location.
- **Fresh window** — default `48h` for a daily run, `30d` for a backfill.
- **Lookback** — default 12 months (an earlier listing counts when its `last_seen_at` falls inside it).
- The client's ICP (for the company gate): `ICP.md` when it exists, else the second brain's ICP page (`hyreflow_knowledge_index`, MCP only). Per-client data, not in this skill.

## Step 1 — Resolve the role to O*NET code(s)
`discover_job_openings` only accepts O*NET occupation codes, not free-text titles. Resolve the role with
the O*NET lookup (`hyreflow_onet_lookup` tool; or the title-index lookup in
[`../references/field-notes.md`](../references/field-notes.md) O*NET section when that tool isn't
available) and **confirm the matched code(s) with the user before spending anything** — the lookup also
returns loose "rank dropped"/root-word matches that can be the wrong occupation entirely.

## Step 2 — Discover candidate roles (`predictleads`, metered)
```bash
hyreflow tools execute predictleads discover_job_openings --payload '{"onet_codes":["41-3091.00"],"location":"Germany","limit":100}' --dry-run
hyreflow tools execute predictleads discover_job_openings --payload '{"onet_codes":["41-3091.00"],"location":"Germany","limit":100}'
```
`onet_codes` is required — see Step 1. **Always pass an explicit `limit`** and preview the call with
`--dry-run` first: this step runs before any company is chosen, so nothing else caps it, and a daily run
would otherwise re-pull every open role in the location. Discovery is priced **per returned result**
(see the cost line in [`../provider-playbooks/predictleads.md`](../provider-playbooks/predictleads.md)) —
the `--dry-run` quote is `limit` × that rate, and the charge is that rate × the rows actually returned.
Scope `onet_codes` and `location` tightly before pulling at volume; check `hyreflow tools get predictleads discover_job_openings`
for the live rate. Output here is companies with a currently-open role in scope — none of them are
confirmed reposts yet.

## Step 3 — Company gate
Drop job boards and staffing/recruiting agencies from the discovery results — they post on behalf of a
client, so the listed "company" is never the actual hirer. Also drop apprenticeship, working-student,
internship, graduate-programme and open-application listings ("Ausbildung", "Werkstudent", "Praktikum",
"Initiativbewerbung", "Trainee", "Talent Program") — O*NET codes them as sales roles, but they aren't a
BD opening.

Each row carries `company_domain` and `company_name` — read the hirer from those, not from the listing
URL (job-board URLs such as heyjobs or stellenwerk point at the board, not the hirer). A row with a
missing or empty `company_domain`: resolve its `relationships.company.data.id` with `predictleads company`.

Take the survivors' domains and run
[`qualify-against-icp.md`](qualify-against-icp.md) — ICP fit + the client's company-size band — before
paying for the history pull in Step 4.

## Step 4 — Scan each surviving company's job-opening history
Run `repost_scan` once per company. It pulls the history for the lookback, applies Step 5's rules in code
and returns only the roles with a signal, each with its evidence:
```bash
hyreflow tools execute hyreflow_native repost_scan --payload '{"domain":"acme.example.com","related_domains":["acme-direct.example.com"],"titles":["Account Executive"],"fresh_days":2}'
```
- `fresh_days` is the fresh window in days (2 for a daily run, 30 for a backfill); `lookback_months`
  defaults to 12.
- Pass the role as `titles`, the way the user names it; add `onet_codes` from Step 1 to catch listings
  posted under another title.
- Pass the company's parent and subsidiary domains as `related_domains` (see below).
- The scan is free. Each history page it pulls bills at the `job_openings` rate: one page per domain, and
  more when a domain has over 1,000 listings. `--dry-run` quotes one page per domain.
- Settle each `needs_review` pair from the two descriptions (`predictleads get_job_opening`). Any
  `warnings` entry (cut-off history, blocked crawl, stale data) means a missing signal is not a "no".

Read the history by hand only when the scan can't run, using the steps below and Step 5.

```bash
hyreflow tools execute predictleads job_openings --payload '{"identifier":"acme.example.com","limit":1000,"last_seen_at_from":"2025-10-12"}'
```
Set `last_seen_at_from` to the **start of the lookback** (today minus 12 months by default): only
listings seen inside the lookback count, and a multi-year history otherwise costs extra 1,000-row pages
and a bigger dataset to read. `job_openings` bills a **flat per-request price for up to 1,000 rows** —
always pass `limit: 1000`, never a small limit "to save credits" (it doesn't). Page through with `page`
if a company's history still runs past 1,000 rows. Also pull the company's **parent and subsidiary domains** (its `meta` carries
`parent_company_domain`, subsidiaries and `redirects_to_domain` — see
[`../provider-playbooks/predictleads.md`](../provider-playbooks/predictleads.md)): a role posted under
`acme.de` and reposted under `acme-direct.de`, or split across `acme.nl`/`acme.com`, is the **same
employer** and has to be read as one history, not two.

Read the history without the descriptions first — full bodies make a 1,000-row dataset several million
characters. With a shell, `hyreflow dataset download` it and work on the CSV locally. Without one, call
`hyreflow_dataset_read` with `columns` — `["attributes.title","attributes.location","attributes.first_seen_at","attributes.last_seen_at","attributes.url"]`,
`format: "csv"`, `limit: 500` — and follow `next_offset` (a page stops early at its size budget);
that reads 1,000 rows in a handful of calls. Fetch a
description only for the pairs Step 5's title test leaves undecided. If the `job_openings` call itself
returned exactly 1,000 rows (its `_meta.row_count`), PredictLeads cut the history off: pull `page: 2` before
treating it as complete.

## Step 5 — Detect the signals
These are the rules `repost_scan` applies. Read them to explain its calls, to settle its `needs_review`
pairs, or to work through a history by hand.

### Same opening?
Two listings are the **same opening** when all of these hold:
- **Same domain or parent/subsidiary domain** (Step 4).
- **Title match that tolerates renames, language switches and seniority changes** — e.g. "Senior
  Business Development Manager" → "Business Development Manager" at Acme GmbH, or "Vertriebsinnendienst" →
  "Inside Sales Manager" at Acme Health. The tolerance stops at the Step 3 exclusions: an apprenticeship,
  working-student or internship listing never matches a full role. When the titles differ by more than
  that — a new qualifier ("certified", "for business customers") or a full rename — compare the
  descriptions: a body that describes the same work (same tasks, site and terms, even if reworded) is the
  same opening; a body describing different work is a different role.
- **Same site.** Take the site from the `location` field; when it gives only the country, or a city that
  holds several of the company's branches (Berlin, Hamburg), read the branch from the title or the
  description (an "Ort:"/"Location:" line, a district name). Acme GmbH's Spandau and Tempelhof branches are
  two sites, not one. A posting that names both places (e.g. "Springfield / Shelbyville" during an office
  move) matches either.

Match on the title and body, never on the row's `onet_data.code`: per-listing codes are unreliable (a
"Hunter" sales role at Acme GmbH came back coded as *Fishing and Hunting Workers*). Derive all timing from
`first_seen_at`/`last_seen_at` — `posted_at` and `status` are usually empty on this endpoint, so don't
gate on them. A listing counts toward the lookback when its `last_seen_at` falls inside it.

Two timing terms used below:
- **Live** — the listing's `last_seen_at` is within 7 days of the **newest `last_seen_at` in that
  company's history** (not today's date: crawl cadence leaves live listings a day or two behind), **and
  that newest `last_seen_at` is itself within 14 days of today**. If the company's newest `last_seen_at`
  is older than that, PredictLeads hasn't crawled it recently: nothing in its history counts as live, so
  don't report long-open or evergreen for it — say its crawl data is stale instead.
- **Chain** — successive listings of the same opening where each new one appears within **3 days** of
  the previous one's `last_seen_at` (a relist under a new ID or a crawl gap). A longer gap means the role
  closed — it may have been filled — so the next listing starts a new chain.

### Repost
A **new listing first seen inside the fresh window**, where **any earlier listing of the same opening**
in the lookback **ran at least 21 days** (`last_seen_at − first_seen_at`) and stopped being seen before
the new one appeared — and **no other listing of the opening overlapped the new one**: every earlier
listing's `last_seen_at` falls before the new listing's `first_seen_at` (allow up to 2 days for crawl
lag). If an earlier listing was still being seen after that, the opening never closed: the new listing is
a parallel copy, so check long-open instead of calling a repost. Earlier listings that ran only a few days
are corrections or crawl blips — skip them when looking for the earlier listing, and don't count them as
cycles. The new listing's own length doesn't matter. Count every earlier listing that ran 21 days or
more as a cycle: three cycles of 98, 77 and 54 days is a far stronger signal than one.

### Long-open
The opening is **live and has been live 90 days or more**, measured from the `first_seen_at` of its
listing, or of the first listing in its chain. No fresh listing needed — the role simply isn't getting
filled.

**Repost wins over long-open.** When the same listings fit both (a ≥21-day listing ends and a new one
in the fresh window picks up within the chain gap), report one **repost** and give the total time open
in its evidence — never report the opening twice.

### Evergreen
**Three or more listings** of the same opening (the first one counts) form a chain at a regular rhythm —
each starting roughly **4–6 weeks** after the previous one started, within a few days of it ending — and
the latest is live. The employer keeps hiring for this role — report it with the cycle count.
When a chain fits both repost and evergreen, the rhythm decides: regular ~monthly back-to-back relists are
evergreen; irregular or longer cycles (54, 77, 98 days) are reposts.

### Overlaps
When a listing fits a reported signal (repost, long-open, evergreen) and also a non-signal (cross-posted,
multi-location), report the signal and mention the parallel listings. When several listings of one opening
are live at the same time, they're one opening (cross-posted) — measure long-open from the oldest of them.

### ATS-migration check
Before calling a repost: count how many of the company's listings on the **same
career-site host** as the new listing (e.g. `acme.career.softgarden.de`) share its `first_seen_at`
(within a few minutes). Three or more on a host the history hasn't seen before, while the listings on
the old host stop being seen around the switch (a few days before or after — crawl gaps blur the exact
day), means the company switched its applicant-tracking system — classify as `ats-migration`, not
repost. The new-host listing **continues the old listing's chain** (same opening, whatever the gap
around the switch), so measure long-open from the old listing's `first_seen_at`. A company with only one or two open roles can't show this pattern; if its single new listing sits
on a host the history has never seen, say a system switch is possible rather than calling it a clean
repost. Leave LinkedIn rows out of this count: LinkedIn timestamps are often rounded (`08:00:00Z`), so
a batch of them can share a timestamp without any switch. A mass relist on the **same** career-site host
(three or more roles' listings ending and reappearing within a day, LinkedIn rows again left out) is a
site relaunch or a crawl gap — treat the relisted listing as a continuation of the old one, not as a
repost.

### Classification
| Pattern | Call it | Report? |
|---|---|---|
| Same opening, an earlier listing ran ≥21 days and ended before the new listing appeared (no overlap), new listing inside the fresh window — one earlier cycle is enough; a regular ~monthly rhythm of 3+ listings is evergreen instead | **repost** | yes — the strongest signal |
| The opening (one listing or a chain) live ≥90 days, e.g. Acme Health's account manager role open since last November | **long-open** | yes — the role isn't getting filled |
| ≥3 listings of the opening in a chain at a ~monthly rhythm, latest live, e.g. Acme Robotics relists its sales role every month | **evergreen** | yes — standing demand for the role |
| Same title opens at a different site for the same company, e.g. Acme GmbH's Berlin opening also appears in Munich | **multi-location** | no — expansion, not a refill |
| The same Acme Health role is live on two portals at once, or two listings of it run in parallel | **cross-posted** | no — one opening, several listings |
| Several of Acme GmbH's roles go live on a new domain/ATS at the same `first_seen_at` (within minutes) while the old listings stop around the switch | **ats-migration** | no — a system switch. The new-host listing continues the old one's chain: if that opening is still live and has been open ≥90 days counting from the old listing's `first_seen_at`, report it as **long-open** |

## Completeness — read the full history before calling "no signal"
`repost_scan` reads the whole history itself and lists in `warnings` anything that left it incomplete.
Reading by hand, `job_openings` can come back **truncated**, or as a dataset reference with only a handful
of rows inline — read the **full** dataset before concluding anything; never compare on the inline
preview alone. **Never report "no repost" (or no long-open /
evergreen) when the history was cut off or incomplete** — say so instead.

## Step 6 — Score the signals
Keep it simple — rank on the signal already in hand, no new tool call (Model A, free):
- signal type: repost, then long-open, then evergreen,
- number of cycles for the same opening (more cycles = harder to fill, or a bigger standing need),
- how long the listings ran (longer = harder to fill),
- seniority of the role,
- ICP fit from Step 3.

Shape the outreach angle to the signal: a repost or long-open role is a search that isn't working ("you've
been looking for this role since spring"); an evergreen role is a recurring need ("you hire for this role
every month — a standing pipeline saves you the relisting").

## Step 7 — Standard tail: enrich → verify → sequence → ATS
This is a **BD opening** (the company has a standing need for the role) — channel is **work email**, never
personal:
- Find the hiring decision-maker — company-scoped `people_search` (HR/Talent lead + the function head for
  the role).
- Enrich work email (`email_enrichment` waterfall) → verify (`enrichley`).
- Confirm the cadence and build the sequence: [`campaign-plays.md`](campaign-plays.md)
  (`start_campaign` is separately gated).
- Land the record in the client's ATS/CRM.

## Pipeline
```
hyreflow_onet_lookup (confirm w/ user) → predictleads discover_job_openings (explicit limit, --dry-run first, per result)
   → company gate (drop boards/agencies + apprenticeship/student/intern listings → qualify vs ICP)
   → hyreflow_native repost_scan per company (+ parent/subsidiary domains; free scan, history pages billed per request)
       = same opening? (same or parent/subsidiary domain + tolerant title match + same site)
       → classify: repost (old listing ≥21d ended, no overlap, new in fresh window; wins over long-open) | long-open (live ≥90d) | evergreen (≥3 monthly relists)
           | not a signal: multi-location | cross-posted | ats-migration
   → settle needs_review pairs from the descriptions
   → score (signal type, cycles, listing age, seniority, ICP fit)
   → enrich work email → verify → sequence → ATS
```

## Guardrails
- **Not LinkedIn's "Reposted" label.** This recipe detects a PredictLeads-derived repost (the title/
  domain/location/timing rules above) — say which signal you're reporting; don't conflate it with
  LinkedIn's own "Reposted" badge, which uses different criteria.
- **`crawler_potentially_blocked: true`** on a company means PredictLeads' crawl coverage for it is
  incomplete — the output must say so, not report a clean "no repost" off partial data.
- **Evidence trail per row.** Every reported signal carries its listings' evidence — for a repost the old
  listing's first/last-seen dates + URL and the new listing's first-seen date + URL; for long-open the
  listing's first-seen date + URL; for evergreen each cycle's dates — so the user can audit the call.
- **Confirm before credit spend.** Both the discovery pull (Step 2, priced per result — cap it with an
  explicit `limit` and preview with `--dry-run`) and the history pull (Step 4, one flat charge per
  1,000-row page) are real spend — pilot one company end-to-end, then apply the Credit & approval gate in
  `SKILL.md` before scaling.
- **Stale crawl ≠ live role.** If a company's newest `last_seen_at` is more than 14 days old, its
  listings aren't live — say the data is stale rather than reporting long-open or evergreen.
