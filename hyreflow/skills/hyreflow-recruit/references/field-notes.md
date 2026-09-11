# Field notes — live-verified provider behavior

Hard-won, live-verified specifics about how each provider actually behaves — filter shapes, billing
units, coverage limits, response quirks — the stuff the vendor docs get wrong or omit. Consult it before
building against a provider.

---

## AI Ark
- **`contact`/`account` filters go at the BODY TOP LEVEL, not under a `filters` key.** Wrapping them as
  `{"filters":{"contact":{...}}}` is silently ignored and returns the entire database. Correct shape:
  `{"page":0,"size":N,"contact":{...},"account":{...}}`.
- **⚠️ `totalElements` ≈ 414,000,000 means your filters were IGNORED, not that you matched a lot** — that
  is the size of the whole database. AI Ark drops a filter key it doesn't recognise, answers 200, and
  serves unfiltered rows. Peek `totalElements` with `size:1` whenever a filter shape is new to you: adding
  a filter must make the count drop.
- **⚠️ Scope a people search to a company via `account.domain` / `account.linkedin` / `account.name` — NOT
  `contact.company`.** `contact.company.{latest,current,previous}` takes AI Ark company UUIDs, and even
  given a company's own correct UUID a live A/B returned an unrelated company inside the top 3 rows, where
  `account.domain` returned 3/3 correct. Pass root domains (`acme.com`, not `https://www.acme.com/about`).
- **A "0 results" answer can be honest.** AI Ark is genuinely thin on some mid-market niches, so a
  correctly scoped search may return nothing. Check `_meta.ignored_query_keys` and `steps[].outcome`
  first — if both are clean, believe the 0 and get coverage from apollo/lusha/leadmagic instead.

- `find_emails` requires a `webhook` in the request — results are pushed to that URL; there is no local
  poll-and-fetch. Without one you get a 400 ("webhook is required") and the job never starts, so the
  `trackId` later 404s as expired/not found.
- `contact.location` is an EXACT-string filter, not a radius — a broad label like "San Francisco Bay
  Area" does not include its cities. Pass the full metro city list (e.g. SF, SF Bay Area, Menlo Park, Palo
  Alto, Mountain View, Sunnyvale, Cupertino, Santa Clara, Redwood City, Oakland, Berkeley, San Jose for the
  Bay Area) — the same enumeration is needed for any metro, and for non-English locales include both
  language variants (people list the metro, not the suburb, so a narrow list under-matches).
- `geoLocation` is an ACCOUNT (company-HQ) filter, not a contact filter — putting it under `contact` is
  silently ignored and returns nationwide results. For the person's own location use `contact.location`
  (string array, exact match, no radius).
- `experience.current.title` SMART matching needs full title forms, not a bare stem — a stem-only query
  (missing a gendered/alternate suffix on a non-English title) can return 0 where the full forms return
  hundreds. **Include gendered forms** (e.g. German `Steuerfachwirt` **and** `Steuerfachwirtin`; the bare
  stem `Steuerfachangestellt` returns 0 where `Steuerfachangestellte`/`-r`/`-n` return hundreds).
- `link.github` coverage is sparse (roughly 1 in 10 sourced people carry it) — don't rely on AI Ark as a
  GitHub-handle source; treat any hit as a bonus and use GitHub search as the fallback lane.
- Working nested filter shape (canonical reference): `account.domain` = `{any:{include:[...]}}`;
  `contact.location` = `{any:{include:[...]}}`; `contact.experience.current.title` =
  `{any:{include:{mode:"SMART","content":[...]}}}`. `size` caps the page; the count/`trackId` sit under the
  `result` envelope (`result.trackId`, `result.totalElements`) — every `tools execute` call returns
  `{ _meta, result }`, so a top-level read yields `None`.
- Response shape: LinkedIn URL at `content[].link.linkedin`, name at `content[].profile.full_name`.
  `people_search` bills per result — check `hyreflow tools get aiark people_search` for the live rate.
- AI Ark is the richest source for candidate `skills`/`inferred_skills` data — other providers mostly
  cross-validate or supply title/LinkedIn rather than independent skill signal, so lead qualification by
  skill should anchor on AI Ark and treat other sources as confirmation. When merging skill evidence across
  sources, combine partial signals (skill A confirmed in one source + skill B in another can jointly
  qualify a candidate) rather than requiring one source to prove everything. Keep keyword-based
  qualification conservative (precision over recall): for a domain tool that's near-universal in a given
  profession, a candidate simply naming the base tool is a reasonable "likely qualified" bar, but check for
  confusion with adjacent/similarly-named tools before trusting a keyword hit alone. Worked example —
  German tax/accounting: **Datev** is near-universal, so a Datev-only skill hit is a fair "likely
  qualified" tier, but **Addison is a different product — don't treat it as a Datev match.**
- Only **FullEnrich**, **LeadMagic**, and **Wiza** return personal emails — AI Ark (like Prospeo and BetterContact) is
  work-email only.

### Via the `people_search` waterfall
- **Both a nested `query` and a flat top-level body work — write whichever reads cleaner.**
  ```json
  {"query": {"company_domains": ["acme.com"], "titles": ["Engineering Manager"]}, "limit": 5}
  ```
  ```json
  {"company_domains": ["acme.com"], "titles": ["Engineering Manager"], "limit": 5}
  ```
  A recognized filter key at the body top level is folded into the query for you. When a field is named
  both ways, the nested `query` wins for that field, under every spelling — a top-level alias never
  outranks the nested canonical. The flat form is what the CLI examples elsewhere in this skill use, so
  either shape is fine; pick nested when you're merging filters programmatically, flat for a quick
  one-off call.
- **Check `_meta.ignored_query_keys` on every search.** A non-empty list means a key you passed matched no
  known filter and narrowed nothing — usually a typo or a provider-native name (`persn_locations`,
  `person_skills`). Treat a wide result set with a non-empty list as unfiltered, not as a big market.
- **A payload where nothing binds is rejected outright, not run unfiltered.** Whether that's because every
  key you passed matched no known filter, or because you passed no filter key at all (an empty query, or
  only `limit`), the call comes back `400` — naming any keys it couldn't place and listing the canonical
  filter keys — a typo or an empty payload costs you an error, not a database-wide sweep billed to your
  workspace. This only fires when *nothing* binds; if some keys bind and others don't, the search still
  runs and the unrecognized ones land in `_meta.ignored_query_keys` as above.
- **`_meta.total_available` ≈ 414,000,000 means no filter applied** — the same tell as above. For an exact
  company scope (domain / company LinkedIn) the step returns `outcome: "filter_not_bound"` instead: the
  rows are discarded, **nothing is charged**, and the waterfall moves to the next provider.
- **A miss can cost more than a hit.** The waterfall stops at the first provider that fills the quota, so
  a well-indexed company settles on one cheap step. A company with thin coverage walks the whole chain
  instead, and the web-search fallbacks at the end of it bill per request for running the search at all,
  regardless of what comes back. Budget a sizing sweep over long-tail or sparsely-indexed companies at
  several times the per-hit rate, not at it.

## Apify
- **Apify is BYOK-only** — the client connects their own Apify token in Integrations. Without one, every
  Apify method returns `no_key`, including the free reads (`list_store_actors`, `get_actor_default_build`,
  `get_actor_input_schema`, `get_run`, `get_dataset_items`). Those reads stay free on Apify's own side; they
  just need the client's key routed through. Hyreflow charges 0 credits for every Apify call — actor
  compute bills the client's own Apify account directly. Same BYOK class as Apollo, Shovels, BuiltWith, and
  ZoomInfo.
- Auth is Bearer, base URL `https://api.apify.com/v2`. Apify bills compute units only on actor RUNS
  (`run_actor_sync`/`run_actor`) — the read/discovery endpoints (`list_store_actors`,
  `get_actor_input_schema`, `get_run`, `get_dataset_items`) are free and safe to call for exploration.
- An actor's input schema does **not** live at `GET /acts/{id}/input-schema` (404 — the endpoint doesn't
  exist). It lives in the actor's default build: `GET /acts/{id}/builds/default`, parse
  `actorDefinition.input` (structured JSON-schema), falling back to the stringified `inputSchema`. Both
  calls are free/read-only. Apify actor ids in URL paths use `username~name` (the `/` becomes `~`).
- Vetted job-scraping actors:
  - Indeed → `misceres/indeed-scraper` (pay-per-event): structured `position`/`location`/`country`
    (enum)/`maxItemsPerSearch`; `parseCompanyDetails` adds cost. No URL building needed.
  - LinkedIn jobs → `fantastic-jobs/advanced-linkedin-job-search-api` (pay-per-event): 39 structured
    filters including `titleSearch`/`locationSearch`/`organizationSearch`/`seniorityFilter`/
    `industryFilter`/`datePostedAfter`/`remote`, plus AI filters (`aiExperienceLevelFilter`/
    `aiVisaSponsorshipFilter`/`aiHasSalary`). Prefer this over `curious_coder/linkedin-jobs-scraper`
    (URL-paste) — structured params beat pasting a search URL.
  - Console actor URLs use the internal actor id; `acts/<id>` resolves to `username/name`, and
    `acts/<id>/builds/default` fetches its schema.

## Apollo
- Apollo is BYOK-only (see Apify above for the shared policy).
- Auth is `x-api-key`. `search_people` is a free preview (`email:null`, no credits charged);
  `enrich_organization` works against a real domain.
- Admin endpoints are key-scope-gated: `list_users` returns 403 "not accessible with this api_key" on a
  standard key — that requires a MASTER key. Not a bug.
- `_paginate`-backed generator methods (`search_people`, `search_organizations`) are **unbounded** —
  driving them through anything that fully consumes the generator (e.g. wrapping in `list()`) walks every
  page and over-fetches. For a bounded call, use the generic request path directly with an explicit
  `per_page`/`page` instead of the generator wrapper.
- `mixed_companies/search` organization objects carry **no `country`/`industry`/employee-count field**
  directly — only `primary_phone` (+ dial code), `publicly_traded_symbol`/`exchange`, `sic_codes`/
  `naics_codes`, `founded_year`, `organization_revenue_printed`, and headcount-growth. You can't
  post-filter by country from the response fields alone.
- Region post-filter trick: derive HQ country from the phone dial code (+31 NL, +32 BE, +358 FI — check
  before +3x, +45 DK, +46 SE, +47 NO). The `organization_locations` query filter leaks multinationals'
  satellite offices, so a phone-country-code post-filter is what actually enforces a region.
- Drop public companies via `publicly_traded_symbol` not null (removes mega-corps a keyword tag pulls in).
  Add `organization_num_employees_ranges` bands to drop both micro shells and giants.
- `q_organization_keyword_tags` is fuzzy — a tag like `"saas"` still pulls in recruitment agencies/media
  that self-tag "saas"; no clean Apollo filter removes them, it needs a manual name/industry pass. Expect
  roughly half the raw results to survive a region+size filter, and roughly half of those again to be
  genuinely industry-relevant after manual review.

## BetterContact
- Auth is `X-API-Key`. Flow is async: `start_enrichment([lead])` → `{id}` → poll `get_enrichment(id)`
  until `status:"terminated"` (roughly 20s for one lead); webhook is optional, local polling works.
- **Pre-terminal states are `not_started`/`in progress`/`processing` — only `terminated` is terminal.**
  Treat every one of those as "not done yet"; a predicate that only checks `!= "in progress"` returns
  early on `not_started`.
- Email lives at the flat field **`contact_email_address`** (+ `_status`, `_provider`), not
  `emails[].email`. Method names are `start_enrichment`/`get_enrichment`.
- Lead input needs only `{first_name, last_name, company_domain}` — no `linkedin_url` required. The
  response also returns deep `company_*`/`contact_*` firmographics.
- `catch_all_safe` is a usable deliverable and a real coverage win: on a catch-all domain the individual
  mailbox can't be bounce-tested, but `catch_all_safe` is graded safe-to-send (standard deliverability
  practice) — use it; `catch_all_not_safe` should be avoided. BetterContact's multi-provider waterfall can
  out-cover a single-source lookup on catch-all domains. These remain **work** emails — BD use, not
  personal-email candidate acquisition (that's FullEnrich/LeadMagic/Wiza).
- Billing: charged once, when the retrieved result carries data — 0.5 credits for an email reveal, 4.8
  for a phone reveal (email included) — check `hyreflow tools get bettercontact start_enrichment` for
  the live rate.

## Exa
- Auth is `x-api-key`. `search(query, num_results=N)` returns real results plus `costDollars` in the
  response itself (e.g. $0.007 for a neural search) along with `resolvedSearchType`/`requestId` — every
  search/contents/answer request reports what it cost, and that reported figure is what the call is billed
  at, so a request that asks for more (results past 10, summaries, extra content types, a deeper `type`)
  costs proportionally more than the base card price.
- A request that matches nothing is still a charged request — Exa prices the request it accepted. Narrow
  the query rather than re-running the same broad one.

## GitHub
- `"<full name>" <org>` (quoted name + free-text org) returns close to zero useful hits — most profiles
  don't list an employer in a searchable field. Use **`<name> in:name`** instead, then verify
  employer/location via `get_user` rather than forcing the org into the query.
- **422 Validation Failed** means a malformed query — also caused by shell quote-escaping when a query is
  built inline; construct the query as a real payload rather than an inline one-liner.
- Commit-harvest email lookup on a matched profile often returns nothing (noreply/private) — treat GitHub
  personal-email recall as a bonus signal, not a primary source.
- Self-reported `company`/`location` on a profile can be stale — trust a people-DB's current-employer
  field over the GitHub bio when they disagree.
- **Gate matches on org confirmation, not name/location alone:** accept a match only if the candidate name
  matches AND the GitHub `company` field confirms the target org. Name-only or location-only hits are
  frequently same-name collisions in the wrong geography — reject them. This deliberately trades coverage
  for precision (the goal is zero false positives, not maximum yield).
- Two distinct usage modes: (a) as a **matcher** against a pre-existing list — low hit rate, since only
  people who list their employer on GitHub pass the org gate (a people-DB-provided GitHub URL, where
  available, is the more reliable signal); (b) as a **discovery source** — a direct `<org> location:<city>`
  user search, org-gated, returns high-precision, useful-yield results (a single search can return a
  double-digit org-confirmed engineering roster). For a pre-existing candidate list, treat GitHub as a
  sparse bonus; for net-new sourcing, run it as its own discovery lane.

## Granola
- Read-only meeting notes/summaries/transcripts. Auth is Bearer (`grn_…`), base URL
  `https://public-api.granola.ai`, cursor pagination.
- Shapes: `GET /v1/notes` returns `notes`/`hasMore`/`cursor` for list pagination; `GET /v1/notes/{id}
  ?include=transcript` fetches a single note with its transcript. Note JSON carries id/title/web_url/
  owner/calendar_event/attendees/folder_membership/transcript/summary_text/summary_markdown; transcript
  items are `{text, start_time, end_time, speaker{source}}`.
- Rate limit is 5 requests/sec — pace detail-fetch loops (roughly 0.15s between calls) rather than relying
  solely on 429-retry, especially for a large `iter_notes` → `get_note` sweep.

## Lemlist
- **`get_campaign_sequences` returns a DICT keyed by sequenceId** (`{ "seq_…": {_id, steps, level} }`),
  not a list — grab the id via `next(iter(resp))`. Passing `None` where a sequence id is expected produces
  a 400 "Match failed".
- `add_lead_to_campaign`: email is optional — a LinkedIn-only lead works with just `linkedin_url`.
- **Lemlist is activation-only, never enrichment.** Leave `findEmail`/`linkedinEnrichment`/`verifyEmail`
  off; enrich upstream (FullEnrich/LeadMagic) before pushing leads in. Confirm the cadence (email vs
  LinkedIn steps) before building — don't assume; see `recipes/campaign-plays.md` for example plays.
- Campaign flow: `POST /api/campaigns` (`{name, timezone, autoReview?}`) creates a campaign AND
  auto-creates an empty sequence + schedule, returning `_id` + `sequenceId`. `POST
  /api/sequences/{sequenceId}/steps` adds a step (`{type:"email", subject, message(HTML), delay(days),
  index}`); `PATCH /api/sequences/steps/{stepId}` updates one. Delete needs the sequence id in the path
  (`DELETE /sequences/{seq}/steps/{id}`; the sequence-less path 405s). No sender is required at campaign or
  step level (assign later). A draft campaign sends nothing until leads are added and it's explicitly
  started — Lemlist can be fully provisioned via API end to end (campaign, sequence, steps, leads).
  **Contrast SourceWhale, which has no create-campaign API at all (UI-only)** — for API-provisioned
  outbound, Lemlist is the sequencer that works end to end.
- Conditional branching: `add_conditional_step(seq, "linkedinInviteAccepted", delay_type="within",
  delay=3)` returns `conditions:[{sequenceId:<accepted>}, {sequenceId, fallback:true}]` — add follow-ups
  into those branch sequence ids.
- People-search real endpoint is `POST /api/database/people` (not the docs-summary-implied
  `/people-database/search`); schema at `GET /api/schema/people`; filters at `GET /api/database/filters`
  (39 filterIds — contact title/location are `currentTitle`/`location`). **Each filter needs BOTH `in` AND
  `out`** — omitting `out` produces a 400 "Parameter filters is invalid".
- Location filters need a superset of metro labels plus language variants and towns — people list the
  metro, not the suburb, so a narrow list under-matches (dropping the English form of a city name alone
  can lose most of the pool).
- Dedupe key: `lead_linkedin_url` is often empty — reconstruct the slug from `canonical_shorthand_name`
  (→ `linkedin.com/in/<name>`) or `linkedin_short`; without this, merge-by-name drops or mis-tags
  Lemlist-only people. For sources with no LinkedIn URL at all (e.g. an external-scrape source), dedupe by
  name instead.
- `skills` populates on only a minority of Lemlist records — don't rely on Lemlist alone to surface
  skill-qualified candidates. Don't qualify on `experiences[].company_description` — it's employer
  marketing copy, not the candidate's own skill signal. Candidate-level signal is `skills`/
  `inferred_skills`/`headline`/experience `title` only (Lemlist experience entries use
  `company_description`; there's no candidate-level description field).

## Lusha
- **Lusha runs on V3** (`api.lusha.com/v3`, search-then-enrich model) — the deprecated V2 (`/v2/person`)
  produces 30s read-timeouts that still bill and `COMPLIANCE_CONTACT_ERROR` responses. Re-check a vendor's
  current API version before trusting a spec-built adapter; vendor docs can move a full major version ahead
  of what an older integration was built against.
- Flow: `search_*` returns a preview (`has` + `canReveal`; `credits:0` means already revealed/free) →
  `enrich_contact_{emails,phones}` reveals by id, or `search_and_enrich_contact_{emails,phones}` does both
  in one call. Convenience `enrich_person_email`/`enrich_person_phone`/`enrich_company` wrap a
  single-target search-and-enrich. Also available: prospecting, lookalikes,
  signals, filter-discovery, `get_usage`.
- **Billing is per matched result, at the price of the field the method reveals** — an `*_email` method
  bills the base rate, its `*_phone` twin several times more; check
  `hyreflow tools get lusha enrich_person_email` for the live rate. There is no field argument, so an
  email-only play never pays for a phone reveal. Lusha bills per call regardless of outcome — a 0-result search still costs the listed
  rate. `canReveal` in the search response tells you whether a field is revealable before you spend
  credits on it.
- `get_usage.used` reflects transient holds that settle, not real spend — the authoritative number per
  call is the response's `billing.creditsCharged`. `get_usage` reads Lusha's own account usage and is
  callable only on a connected Lusha key; reconcile the workspace's total spend via
  `hyreflow session usage` / `hyreflow billing balance` instead.
- Coverage varies sharply by segment: Lusha has weak/suppressed coverage of large-tech-employer staff
  (opt-out/compliance), but solid general US B2B coverage (roughly a quarter of contacts match, with a
  smaller fraction revealable). Always search-preview first (cheap) to read the match rate and `canReveal`
  before spending reveal credits — don't assume coverage from vendor reputation alone.
- Phone reveal returns a real direct-dial number; each phone carries a `doNotCall` compliance
  flag — check it before dialing.
- Channel rule: Lusha, like AI Ark and Prospeo, is work-email/BD only — personal emails come from
  FullEnrich/LeadMagic/Wiza.

## O*NET title → code resolution
- `discover_job_openings` (PredictLeads) needs `onet_codes`, but customers speak in job titles. Never let
  the agent recall a code from memory — a hallucinated code silently returns wrong results and wastes
  credits. Instead, resolve titles against two O*NET reference tables served by the engine: a flat title
  index (one `Job Title | CODE` per line — official + commonly reported titles) and an occupations index
  (`CODE | Title | description`) for disambiguation.
- **Fetch each table once, then search the local copy** — never read either one whole into context (the
  title index alone is ~2 MB) and never re-fetch per lookup:
  ```bash
  curl -fsS https://recruit.hyreflow.ai/api/v2/reference/onet/titles.md -o /tmp/onet-titles.md
  curl -fsS https://recruit.hyreflow.ai/api/v2/reference/onet/occupations.md -o /tmp/onet-occupations.md
  ```
  Then resolve titles with a line-matching content search (`grep`, your harness's `search_files`, or
  equivalent) over the local files.
- Keep search-target reference lines short: putting many synonyms on one line per occupation makes
  load-bearing lines (developer/sales/manager) thousands of characters long, and long matching lines get
  truncated/hidden by search tools — hiding the code you needed. One title per line keeps every match's
  code visible.
- Search cost is line-matched, not file-sized — alternate titles don't bloat context (only matched lines
  load), and they're what makes informal titles ("AE", "SDR") resolve. Workflow: fetch both tables once →
  search the title index → root-word fallback → disambiguate via the occupations file → confirm with the
  user if still ambiguous → emit only codes present in the files.

## PredictLeads
- **Billing is not uniform across company endpoints — check the rate before assuming it.**
  `similar_companies` bills PER RECORD returned, so an unbounded top-20 default racks up 20x the
  per-record rate — always cap `limit`. `financing_events`/`job_openings`/`news_events`/
  `technology_detections` each return a single record per call, so they bill once per response
  regardless of what's inside it. Check `hyreflow tools get predictleads <method>` for the live rate on
  each.
- `discover_job_openings` **without `onet_codes` times out** (30s read-timeout, scanning everything) and
  does not bill; with an O*NET code it returns instantly — always pass `onet_codes`. `job_openings(domain)`
  is a separate, company-scoped hiring endpoint, distinct from `discover_job_openings` (which is
  O*NET-code-keyed cross-company discovery).
- `api_subscription` is free and doubles as an auth check; it reads PredictLeads' own subscription/balance
  and is callable only on a connected PredictLeads key. Each `discover_*` record is charged in Hyreflow
  credits — check `hyreflow billing balance`.
- `financing_events(domain)` is the cheap, reliable path: full round history plus investor companies plus
  a `meta.message` listing subsidiary domains to try, for one charge per response regardless of record
  count.
- Records are not returned in strict chronological order — sort by `effective_date`/`found_at` for
  "latest," don't assume ordering.
- Source quality varies: large recent rounds cite solid sources; smaller/older ones can cite weak
  blogs — treat `source_urls` as signal, not gospel.
- `news_events.location_data` is noisy fuzzy-geo — don't trust it as a precise location.
- `technology_detections` are mostly `score:0.25, source_count:1, seen_on_job_openings` — inferred from a
  single job posting, not confirmed on-site. Filter by score/source_count for confidence; only
  higher-score/subpage-seen detections are solid.
- Most company-scoped read methods beyond the ones above (`company`, `similar_companies`, `connections`,
  `products`, `github_repositories`, `website_evolution`), most of the `discover_*` family, `technologies`,
  all `get_*`-by-id calls, `iter_*` pagination, and `follow`/`unfollow`/`followings` remain spot-checked
  only lightly or not at all — treat them as docs-only until verified against a real response.

## Prospeo
- **No person-level profile-keyword/skills filter exists.** `person_skills` isn't a real filter
  (`INVALID_FILTERS`); `person_search` does not match profile-wide — it matches names/titles only, not
  arbitrary skill keywords; `company_keywords` scopes companies, not people. For "people with `<skill>` in
  their profile" queries, use AI Ark instead.
- Prospeo's `company_funding` filter is a silent no-op while it is under vendor maintenance (last verified
  2026-07): it accepts any value — including a nonsense funding-round string — and returns the entire
  unfiltered pool with no error, instead of raising `INVALID_FILTERS` like every other bad filter value.
  Never use it; funding queries route to AI Ark instead. Prospeo's other funding and hiring-signal filters
  are also under vendor maintenance as of the same check — re-verify before relying on any of them.
- `person_location_search` values MUST come from `search_suggestions` — arbitrary strings return
  `INVALID_FILTERS`. A ZONE suggestion (e.g. "Greater Munich Metropolitan Area, Germany") covers a metro
  radius in one value — unlike AI Ark's `contact.location` or Lemlist's `location`, which need enumerated
  city lists. A location suggestion string can carry a `" #<COUNTRY_CODE>"` suffix in the UI; that suffix
  is UI-internal only — the API accepts and returns plain canonical suggestion names.
- Seniority enum spelling matters: `"C-Suite"`, not `"C-Level"` (wrong spelling → `INVALID_FILTERS`). Full
  verbatim enums (seniority, hierarchical departments, ~250 industries, headcount buckets, funding stages,
  technology list) are documented in `reference/docs/prospeo/raw/search-person-filters.md`.
- `person_job_title` with `match_mode:"SIMILAR"` only expands **within the seed title's seniority level**
  — `SIMILAR "Software Engineer"` intersected with a Senior seniority filter returns nothing (it never
  reaches "Senior Software Engineer"). When combining a title with `person_seniority`, use `"CONTAINS"`
  instead. `CONTAINS` itself matches on a substring/stem, so a bare word stem missing a gendered or
  alternate suffix can under-match relative to the full title forms.
- `company_headcount_growth.departments` has its own 19-value enum, case-sensitive, distinct from
  `person_department`: Medical, Sales, HR, Legal, Marketing, Finance, Technical, Consulting, Operations,
  Product, General management, Administrative, Customer service, Project management, Design / UI / UX,
  Research, Trades, Real estate, Education. Engineering growth is `"Technical"` (not "Engineering &
  Technical"), and casing matters (`"Customer service"`/`"Real estate"`, not `"Customer Service"`/`"Real
  Estate"`).
- `person_department` accepts a top-level or a sub-level value — a top-level value (e.g. "Sales")
  auto-includes all its sub-departments; a sub-level value targets just that niche.
- Other verified filter shapes: `company_headcount_range` is a bare bucket array; `company_revenue`
  min/max are bucket strings (e.g. `"<100K"`); `company_founded` is `{min,max,include_unknown_founded}`;
  `company_headcount_growth` is `{timeframe_month,min,max,departments[]}`; `company_type` is a rich object.
- `INVALID_FILTERS` responses surface `provider_error_code` + `provider_detail.filter_error` naming which
  filter was rejected, rather than a bare message.
- Flow/billing: `search_suggestions` bills 0.1 credits on a direct call (free inside a `people_search`
  waterfall) and `search_person` bills 0.4 credits per request (25/page), with 30-day dedup on repeat
  calls. Results carry `person`+`company` but no email/mobile — enrich the `person_id` separately
  (`enrich_person`; `enrich_mobile=True` reveals a mobile at a higher rate than an email reveal — check
  `hyreflow tools get prospeo enrich_person` for the live rates). The job-change filter has schema drift — use
  FullEnrich for that instead. `skills` fields are essentially never populated on search results — treat
  Prospeo as a title/LinkedIn cross-validation source for skill-based qualification, not an independent one.

## Recruit CRM
- 🔴 **The Open API is plan-gated.** `list_candidates`/search/create all return 401
  `INSUFFICIENT_ACCESS` ("Please Upgrade Your Plan to 'Business' or 'Enterprise'") even with a valid key —
  the account's plan tier blocks the entire Open API, both read and write. Until the account is on
  Business/Enterprise, fall back to CSV export or another ATS (Loxo/Vincere/Recruiterflow/Atlas/Bullhorn)
  for candidate/company landing.

## Shovels
- 🔴 **EEO compliance warning:** `get_contractor_employees` records also carry gender/age/marital
  status/children/income/net_worth fields. **Never use these for candidate screening — it's illegal.** Use
  only `job_title`/`seniority_level`/`department`/location.
- **Shovels is BYOK-only** — every call is 0 Hyreflow credits, billed instead against the client's own
  connected Shovels account. `get_contractor_permits` has **no size cap** — gate `size` on a large
  contractor to control the client's own Shovels spend, not ours.
- `get_contractor_employees`, when populated, is a full candidate database: each employee record carries
  name, job_title, seniority_level, department, phone, a personal email, a work email
  (`business_email`), an individual LinkedIn URL, and address. That makes Shovels a primary,
  compliance-clean candidate source for construction recruiting — contractor = hiring signal, employees =
  named tradespeople/staff, no further enrichment needed. But the roster is frequently empty and coverage
  is market-dependent (an electrical-contractor sweep of one metro returned 0 employees for every firm
  tried) — treat it as a bonus and fall back to general people-DBs/Exa when empty.
- Field richness in `search_contractors` scales with contractor SIZE, not a blanket rule. A small/solo
  operator's record is mostly null (roughly 20–25 of 34 fields empty; only name, business_name, phone,
  `tag_tally`, permit_count, status_tally, job value, rating, and address.state reliably populate). An
  established firm (dozens of employees, 1,000+ permits) comes back fully populated instead: company
  `linkedin_url`, multiple comma-separated emails (including a corporate address you can derive a domain
  from), multiple phones, `dba`, license + classification + dates, revenue, employee_count, industry, full
  address + latlng, rating/reviews. Don't generalize field population from one small sample.
- Trade lives in `tag_tally` (and `classification_derived` when populated), not
  `contractor_classification_derived` alone — filtering `contractor_classification_derived="solar"` (or
  any free-text guess) returns 0. Discover valid trade values via `list_tags` before filtering.
- BD contact chain by firm size: for a small/mid firm, the owner returned by `search_contractors` is often
  the hiring manager — contact directly. For a larger firm, use the returned LinkedIn company URL/domain as
  an entry point into Apollo/Lusha to find the named ops/hiring lead.
- Many "contractors" surfaced by `search_contractors` are individual sole-proprietors/small licensed
  operators — reachable directly as named tradespeople via waterfall enrichment (FullEnrich/LeadMagic/Wiza)
  on name + location. The primary use case is still BD (find growing firms that need to hire, sell
  recruiting services), but treating every hit as a companies-only database undersells it.
- Response envelope: `{items, size, total_count, next_cursor}` — pass `include_count` to get the total.
- `get_contractor(id)` and `get_contractor_metrics` are unreliable via their by-id path in this adapter —
  `search_contractors` already returns the same fields, so prefer search over by-id lookups.
- Verify capability claims against live data, not vendor-adjacent third-party write-ups — they can
  understate (or overstate) what the raw API actually returns.

## Wiza
- Auth is Bearer, base `https://wiza.co/api`. Reveals and list operations are async.
- **Billing gotcha: the API spends a separate `api_credits` pool, not the plan's `email_credits`/
  `phone_credits`.** A reveal can fail with `status:"failed"`, `fail_error:"billing_issue"` even when
  `email_credits`/`phone_credits` show a healthy balance, if `api_credits` is 0. `get_credits` reads
  Wiza's own account credit pools and is callable only on a connected Wiza key; a reveal that fails for
  billing reasons charges nothing regardless. Budget the run against `hyreflow billing balance`.

## Multi-source sourcing (cross-provider)
> Full workflow and every gotcha in one place: **`recipes/multi-source-candidate-search.md`**.
- **Count-peek before paying.** All three people-DBs return a total, nested under the `result` envelope —
  AI Ark `result.totalElements`, Lemlist `result.total`, Prospeo `result.pagination.total_count` (every
  `tools execute` returns `{ _meta, result }`, so a top-level read yields `None`). A `size:1` / `page:1`
  call reads the total cheaply: you pay per page/result, never for the whole pool up front. Billing
  differs by provider — check `hyreflow tools get <tool> <method>` for the live rate before scaling up.
- **Dedupe by LinkedIn slug** across sources; fall back to name for sources that carry no LinkedIn URL.
  Xing is usable as an external-scrape fourth source — rich `scraped_tags`, but no LinkedIn URL, so it
  dedupes by name only.
- **Merge skill evidence across sources** rather than requiring one source to prove everything: skill A
  confirmed in one DB plus skill B in another can jointly qualify a candidate.

## Async jobs / polling
- **Enumerate every pre-terminal state, not just the first/obvious one, when writing a terminal-status
  predicate.** Stopping on the wrong state ends the poll before the job is actually done.
- Per-provider terminal states: BetterContact → `terminated` (pre-terminal: `not_started`/`in progress`/
  `processing`); Apify `get_run` → `SUCCEEDED` (plus other run-status values); AI Ark export/email-finder →
  `DONE`, except `find_emails`, which is webhook/push-only with no local poll at all — a webhook URL is
  required up front, and skipping it leaves the job id 404-ing as expired/not found since the job never
  starts; Wiza reveal jobs → poll to a terminal status and check `fail_error` on failure (e.g.
  `billing_issue`).
