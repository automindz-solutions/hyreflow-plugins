# Finding people (sourcing stage)

**L2 phase doc.** How to run the *discovery* stage well — turn a query (or a company from a signal) into a
deduped list of the right people. Sits between [`references/provider-precedence.md`](references/provider-precedence.md)
(which provider) and the `recipes/` (specific plays). Read before any people search.

> Don't have rows/criteria yet? You're upstream of this doc. Get the company/ICP/query first.

## The one mental model — the `people_search` waterfall tool (DEFAULT)
You source by calling the **`people_search` waterfall tool** with ONE **canonical query** — the engine
runs the multi-provider waterfall for you:

```
hyreflow tools execute people_search --payload '{<canonical query>}'
hyreflow tools execute people_search --payload '{...}' --dry-run   # preview the provider plan, no call/charge
```

Canonical query fields (all optional, combine what you have):
`titles`, `skills`, `locations` (or `person_locations`), `company_names`, `company_domains`,
`company_linkedin_urls`, `seniority`, `certifications`, `keywords`, `min_experience_years`, `limit`,
`coverage` (`single` = stop once `limit` people are collected, the default · `max` = exhaustive deduped
union across every provider),
`providers` (optional allowlist — **pin the waterfall to a subset**, house order preserved, e.g.
`"providers":["aiark"]` for "only ai ark"; still goes through the engine's correct per-provider mapper).

> **For IT/role sourcing, `skills` is the precision lever — use it over title-only filtering.** It's
> pushed down to aiark `contact.skill` (SMART match) and **prefilters at the source**, instead of a
> broad title-only pull + client-side filtering of the returned `skills[]` (which wastes credits on
> off-target rows). E.g. Python/FastAPI backend engineers → pass `"skills": ["Python","FastAPI"]`
> alongside the title rather than relying on the title alone.

The engine walks the **house provider order** (configured in `reference/waterfalls.json` — never restate
the order here), maps your canonical query to each provider's native shape, dedups, pages,
and **stops at the first source(s) that fill `limit`** (a "hit"); thin/empty providers fall through to top
up. Only the providers that actually return rows are billed. **The engine owns the loop** — you don't
hand-write per-provider filters or manage dedup/paging.

**Company-scoped queries also reach the public web.** The last steps of the chain search the open web
(structured people search first, LinkedIn profile search second) and run **only** for a query that names a
company — and, under the default `coverage:"single"`, only once the people databases have failed to fill
`limit`. That's the coverage case they exist for: a seed-stage company the databases hold no rows for at
all. You don't reach for them by hand inside a company-scoped search — one `people_search` call already
covers it. (`coverage:"max"` is exhaustive by definition, so it runs them alongside everything else.)
- A row is kept only if the person's current company matches the company you asked for **as a whole
  name**, so name collisions (people at unrelated companies that share the search term) never reach you —
  a query for `acme` against `GoAcme` or `Acmeteer` is a different company and its people are dropped, while
  a truncation of the same name (`Acme Corp` matching `Acme Corporation`) or a spelling variant (`Acme
  Inc`, `ACME-Inc`, a domain brand like `acmelabs` for `Acme Labs`) can still match. When a web step
  returned rows but none could be verified as at the requested company, that step reports `outcome:
  "company_mismatch"` with `verify_dropped` (how many rows were dropped) — distinguishing a leg that
  contributed nothing from one that found nobody at all.
- These steps read the company anchor plus `titles`, `locations`, `seniority`, `keywords`,
  `min_experience_years`. A query carrying `skills`, a tenure window, `departments` or firmographics stops
  at the databases — a web result can't prove those, so it isn't asked to.
- A row with **`verification_required: true`** came from a profile *search result*, not a profile record:
  confirm the company and title on the profile before you ship or contact it. `_meta.warnings` counts them.
- A web search is charged per request whether or not it finds anyone (a people-DB miss stays free).

**No-result retry rule:** if a narrow `people_search` returns 0 rows (or too few), broaden the canonical
query and call `people_search` again — **on a company-scoped retry, the title filter is a precision lever:
widen it, never remove it.** Expand `titles[]` with more role variants (paste from the canonical lists in
§Title handling below), and/or add `seniority` and `skills`. Loosen location if allowed.
**Never drop `titles[]` entirely** to
"broaden" a company-scoped search — on a `company_domains`/`company_names`-scoped query, an empty `titles[]`
returns the WHOLE roster (every function: sales, talent, policy, partnerships, leadership …) plus
self-declared-employer noise (people who merely list the company on LinkedIn — open-to-work profiles,
unrelated professions), which you then have to guess-filter client-side from freeform headlines. That's
slower, less precise, and — on a large company — an expensive, unbounded pull. Server-side title filtering
is cheaper and more precise than a broad pull + client-side filter. Do **not** switch to
`apollo_search_people` for a broader-title retry unless the user explicitly requested Apollo-only/
provider-native control and Apollo BYOK is configured. Do not bypass the waterfall just because the first
canonical query missed.

```
hyreflow tools execute people_search --payload '{
  "titles": ["Software Engineer"],
  "skills": ["Python", "FastAPI"],
  "locations": ["United States"],
  "company_domains": ["meta.com"],
  "limit": 5 }'
```

→ a deduped list of people (each tagged with its `_source` provider; LinkedIn/last-name obfuscated until
you enrich). Discover it like any tool: `hyreflow tools search people` · `hyreflow tools get people_search`.

### Advanced — a single provider's flat search tool (NOT the default)
Drop to one provider's flat search **only** when you need provider-level control of the native filters,
or the user names a specific provider. Apollo flat tools are BYOK-only, so confirm Apollo BYOK before using
`apollo_*`. Then **YOU own the loop**: dedup, count-before-pay, paging, and topping up from a second provider
if the first is thin.

```
hyreflow tools execute apollo_search_people --payload '{
  "person_titles": ["Software Engineer"],
  "person_locations": ["United States"],
  "q_organization_domains_list": ["meta.com"],
  "per_page": 3 }'
```

Each provider's exact native payload is in its `provider-playbooks/<tool>.md`; the company-scope field
per provider is the table below (`aiark_people_search`, `prospeo_search_person`,
`lemlist_search_people_database`, `apollo_search_people`).

## Two shapes of query (know which you have)
1. **Open query** — titles + location (e.g. "CTOs in Germany"). No company anchor.
2. **Company-targeted** — you start from a *company* (a funding/jobs/layoff signal, a target account) and want
   the people *at* it. This is the common BD/sourcing trigger.

## Company-targeted = scope by the field THIS provider uses
Each provider scopes to a company by a **different native field** — use the right one for the provider
you picked. Prefer **domain** (every provider supports it); fall back to company LinkedIn or name.

| Provider (flat tool) | Native company-scope field | Needs (min) |
|---|---|---|
| **`apollo_search_people`** | `q_organization_domains_list` (**domain only**) | **domain** |
| **`aiark_people_search`** | `account.domain` \| `account.linkedin` \| `account.name` | any one |
| **`prospeo_search_person`** | `company` (name) — geo needs pre-resolve | name |
| **`lemlist_search_people_database`** | `currentCompanyWebsiteUrl` (domain) \| `currentCompanyLinkedInUrl` \| `currentCompany` (name) | any one |

→ Have only a **name**? Use aiark/prospeo/lemlist (apollo people-search needs a domain). Have a
**domain**? Any of them works; use the `people_search` waterfall by default. If a search returns global/title-only noise (no
company scope applied), you used the wrong native field — fix the payload, don't ship the rows.

## Run discipline (YOU own these now — the credits depend on it)
- **One provider, then top up.** Call your first choice; if it returns **< N**, call the next provider
  and dedup the union. Stop the instant you have N. Don't fan out to every provider by default.
- **A job-scrape shortfall is a BOARD gap, not a title gap.** The retry ladder in this doc (widen
  `titles[]`, add `seniority`/`skills`) belongs to `people_search`. When an open-roles scrape returns
  **< N**, add the next **board** and dedup the union — a Germany-scoped run adds `arbeitsagentur_jobs`
  (the German federal board), which indexes roles the global boards don't carry. Re-running the same
  board with a different title spends credits on the same index. Boards and payload shapes:
  [`provider-playbooks/hyreflow_native.md`](provider-playbooks/hyreflow_native.md).
- **Count-before-pay.** Every people-DB returns a total (apollo `total_entries`, aiark `totalElements`,
  prospeo `pagination.total_count`, lemlist `total`). `--dry-run` or peek the count before pulling
  depth — never blind-paginate a paid source. The count sits under the `result` envelope every
  `tools execute` returns (`{ _meta, result }`), so read it as `result.totalElements` /
  `result.total_entries` / etc. — a top-level read returns `None`.
- **Over-provision ~1.4×N then filter.** Coverage is a **property of the person/company**, not effort: a
  20-person startup or a bare profile has near-zero coverage across *every* provider. Don't chase missing rows.
- **The pilot IS a separate call — don't combine it with the full pull.** Two calls in order:
  **(1) pilot/peek `size:1`** → reads `result.totalElements` (count-before-pay) and returns one sample record.
  This single call is your approval-gate pilot. **(2) After approval**, the full call sets
  `limit = ⌈1.4 × N⌉` (for N=10, set size:14), then deliver the best **N complete** rows.
  Set `limit` to the over-provisioned number — not raw N.
- **Dedup is on YOU** — key on `linkedin_url`, fall back to name+company. Normalize identity to
  `linkedin_url` across providers; don't trust a provider's raw id when merging two sources.
- **Narrate long runs in a session.** For a multi-step sourcing+enrich job, open a session so the user
  sees live progress in the Playground: `hyreflow session start --steps '[...]' --user-prompt "..."`
  (then `session update`/`status`/`output` as you go). Single quick search → skip it.

## Provider quirks worth knowing (full native payloads in each `provider-playbooks/<tool>.md`)
- **aiark** — richest profiles; carries skills/headline. **Deeply nested `contact`/`account` filter** you
  build by hand (see `provider-playbooks/aiark.md` for the exact shape). Best company coverage of the four.
  **Only DB with an "open to work" candidate signal** — pass canonical `profile_badges:["OPEN_TO_WORK"]` to
  `people_search` (it maps to `contact.profileBadge` and pins the chain to aiark; hand-building the raw
  adapter payload is only needed for filters the canonical query can't express — see `provider-playbooks/aiark.md`).
  Route any *open-to-work* request to aiark. Pair it with title/location/skill — `OPEN_TO_WORK` alone matches a ~24M global pool.
  Open-to-work is one of several **recruitability signals** (with tenure, job-change cadence, seniority band) —
  see [`recruiter-craft.md`](recruiter-craft.md) §A for when to reframe a search around them.
- **prospeo** — strong DB. Pass `locations` as raw names on the canonical `people_search` query (`"United
  States"`, `"munich"`) — the engine resolves them to Prospeo's canonical tokens for you. Only the **flat**
  `prospeo_search_person` tool needs pre-resolution by hand: call `prospeo search_suggestions` (free) with
  the raw location and pass the top suggestion's `name` (raw strings → `INVALID_FILTERS`). A **title+company combo that
  matches nobody** (tiny/new co, or a title spelled differently than the company stores it) is a **clean
  miss** — the waterfall just falls through to the next provider; not an outage. Widen with the title rule
  below before assuming there's no coverage.
- **lemlist** — People DB scopes by domain/LinkedIn/name; current company is `current_exp_company_name` (NOT
  `experiences[0]`, which can be a past role). `currentTitle` accepts free text.
- **apollo** — free net-new preview but **obfuscates PII** (no LinkedIn/last name until you enrich); scopes by
  **domain only**. Good as a coverage fallback, weaker as a primary for company-targeted.

## No coverage in the people-DBs → X-ray the public web (`serper`)
Some targets are absent from every people-DB, not thinly covered: pre-revenue startups, niche verticals,
non-US markets, and local/SMB businesses (trades, clinics, single-site agencies). A **company-scoped**
`people_search` already ends on the public web for exactly this case (see the waterfall section above), so
run the broadened retry first and read its `exa` / `serper` steps before searching by hand. Drive the web
yourself for what the waterfall deliberately doesn't cover: an **open** query with no company anchor, a
segment that needs `serper maps`, a Boolean string you want full control over, or URL recovery.

- **Scoped `site:` X-ray** — `serper search` with the Boolean string from
  [`references/recruiter-playbooks/boolean-search.md`](references/recruiter-playbooks/boolean-search.md).
  `site:` plus quoted phrases is what makes it precise; keyword soup without `site:` returns noise.
- **Local / SMB** — `serper maps` for storefront and service-area businesses. It returns phone, address,
  website and rating, which is exactly the data the people-DBs don't hold for this segment.

```
hyreflow tools execute serper search --payload '{"query":"site:linkedin.com/in (\"data engineer\" OR \"analytics engineer\") (spark OR airflow) \"San Francisco\"","num":10}'
hyreflow tools execute serper maps --payload '{"query":"HVAC contractors Leverkusen","gl":"de","hl":"de"}'
```

- **The payload key is `query`, not `q`.** Optional: `num` (depth), `gl` / `hl` (country / language —
  results default to US English, so set both for any other market), `location`, `page`.
- **0.1 credits per call, charged whether or not the query finds anything** — it's a real search, so budget
  per query, not per usable hit. A pilot query first, then depth.
- **X-ray hits are leads, not a list.** A public profile carries no verified email or phone and its title
  may be stale. Feed the names back into a company-scoped `people_search` (or enrichment) to get canonical
  records before you ship or sequence them.
- Need the content behind a hit? `serper scrape` returns one page as text; prefer `firecrawl` for
  JS-rendered pages.

## URL recovery — you know who, you need the URL
Enrichment tools want a LinkedIn URL (lusha rejects anything that isn't `linkedin.com/in/…`). When you have
a name plus company and need that URL, search for it instead of guessing:

```
# person — always include company + role context
hyreflow tools execute serper search --payload '{"query":"\"Jane Smith\" \"Acme\" \"sales ops\" site:linkedin.com/in","num":5}'
# company
hyreflow tools execute serper search --payload '{"query":"\"Acme\" site:linkedin.com/company","num":3}'
```

- A bare name matches the wrong person constantly — company and role context are what make the hit real.
- **Take the URL only when the hit is unambiguous; otherwise leave it null.** A wrong LinkedIn URL poisons
  every enrichment downstream of it, and a null is cheap to fill later.
- For *identity* questions ("who is the {title} at {company}?"), `exa.answer` is metered (0 credits) — ask
  it first. Reach for `serper` when you already know the string and want the deterministic URL lookup.

## Location handling — search the commutable AREA, not just the city (UNIVERSAL RULE)
For **on-site / hybrid / local** roles, expand the stated location to its **commutable metro / neighbouring cities**
and pass them all in `locations[]` (people-DBs accept a city-name list; aiark also buckets metros, e.g. "Cologne Bonn Region"):
- **A city is named** → add the realistic **daily-commute belt**, closer cities weighted higher.
  e.g. **Köln → Bonn, Leverkusen, Düsseldorf** · München → Augsburg/Ingolstadt · Frankfurt → Mainz/Wiesbaden/Darmstadt.
- **A radius is given** ("within 50 km of X") → derive the towns/cities inside that radius and search those.
- **Remote** with no geo/language requirement → location doesn't matter (see `provider-precedence.md` remote rule).
- **Match the expansion to the work model** — don't pull a 90-min-away city for a strict daily-on-site role; widen more for hybrid.

## Title handling — search the job FUNCTION, not one label (UNIVERSAL RULE)
A user's title is a *label for a role*, not the exact string the person carries. One title in `titles[]`
under-searches: "VP of Sales" the literal substring misses "Vice President, Sales", "SVP Sales", and the
person who actually owns that number under a different name. **Expand every requested title into the set of
strings that name the same job, and pass them all in `titles[]`** (the engine dedups results):
- **Spelling / scope variants** — abbreviation ↔ full word and rank scope: `VP ↔ Vice President`,
  add `SVP / EVP / AVP / Regional VP`, comma vs "of" (`VP of Sales` + `Vice President, Sales`).
- **Functional equivalents** — the *same job under other names*: **VP of Sales → VP of Revenue, Chief
  Revenue Officer (CRO), Head of Sales, Sales Director, VP Commercial**. (Eng → "VP Engineering, VP
  Technology, Head of Engineering, CTO"; Marketing → "VP Marketing, CMO, Head of Growth/Demand Gen".)
- **Or go seniority + function** when you don't know the exact label: `seniority:["Vice President"]` plus a
  function keyword/department beats guessing one title — robust when the org structure is unknown.
- **Match breadth to how much you know** — exact title from a JD/known org chart → keep it tight; vague ask
  ("find me the VP of Sales") or unknown company structure → cast wider with the equivalents above.
- **Gendered/inflected variants still apply** (e.g. German `Steuerfachwirt`/`-in`) — see
  `recipes/multi-source-candidate-search.md`. The engine also fuzz-expands per provider (Prospeo `SIMILAR`,
  Apollo similar-titles, aiark `SMART`), but that's a backstop — **lead with an explicit expanded list.**

### Canonical role-family variant lists — paste directly into `titles[]` on a retry
Individual-contributor roles don't have a VP-style rank ladder to widen along — widen the LABEL instead.
These are starting sets to expand; add JD-specific variants on top, and keep at least one title-family
term in `titles[]` (never retry with an empty title list on a company-scoped search — see the retry rule above).
- **Software / ML engineer:** `Software Engineer, Senior Software Engineer, Staff Software Engineer,
  Member of Technical Staff, Research Engineer, ML Engineer, Machine Learning Engineer, Infrastructure
  Engineer, Platform Engineer, Backend Engineer, Frontend Engineer, Fullstack Engineer, Applied AI
  Engineer, SDE, Software Development Engineer`.
- **Data:** `Data Engineer, Data Scientist, Analytics Engineer, ML Ops Engineer, MLOps Engineer, Data
  Platform Engineer`.
- **Product:** `Product Manager, Senior Product Manager, Group Product Manager, Technical Product
  Manager, Associate Product Manager, APM`.
- **Design:** `Product Designer, UX Designer, UI Designer, Interaction Designer, UX Researcher`.
- **Sales/GTM ICs:** `Account Executive, AE, Sales Development Representative, SDR, Business Development
  Representative, BDR, Customer Success Manager, CSM`.

## Hiring-manager identification — reporting-line first (UNIVERSAL RULE)
When the task is "find the hiring manager for this role" (BD, competitor-intel, or any JD-driven search):

**If the JD names a reporting line, that named role IS the hiring manager — find that *specific* person first.**
Watch for: *"you will report directly to the {Head of Sales / VP Engineering / …}"*, *"reports to {title}"*, or an
**interview-panel title** (e.g. *"90-min deep dive with the Regional Director DACH"* → you'd report to the Regional Director DACH).

**The interview process is the richest source — it usually names the WHOLE chain.** Example:
*"Screening with Joost/Adam → deep-dive with the Regional Director DACH → VP Continental Europe → SVP EMEA Enterprise."*
- **Separate agency from client:** named individuals tied to the agency (the recruiter screeners) are NOT at the client — discard them. **Client-side org *titles* (Regional Director DACH, VP …, SVP …)** are the hire's reporting chain.
- Extract every client-side title → find each person at the company → you get the **hiring manager + the escalation chain**.
  Great for BD: own the direct manager, but **multi-thread** the account by referencing the VP/SVP above.

1. **Extract `reports_to`** during JD parsing (the named manager role).
2. **exa FIRST** — `exa.answer("Who is the {reports_to} at {company}?")` (or `exa.search`) → the specific person + LinkedIn. Each request is charged whether or not it lands, so ask once with a named role rather than re-running variations.
   Got the name but no URL? Recover it with the `serper` `site:linkedin.com/in` lookup above.
3. **Verify** with a targeted company-scoped flat search (e.g. `apollo_search_people` with that title +
   `q_organization_domains_list`) → canonical record + LinkedIn.
4. **Fallback only if no reporting line is named** (or the person isn't found): the broad leadership sweep (search the
   relevant leadership titles at the company).

This is more precise and cheaper than sweeping all leadership — the JD usually tells you exactly who owns the hire.

## Gates
- **EEO:** never filter candidates on gender/age/marital status/children/income. Hard rule.
- **ICP qualify BEFORE contact enrichment** (next stage) — don't pay to enrich non-fit people's contact
  details. Enrich `linkedin_profile` (dated work history) first if the pool is thin — qualify needs it to
  score on more than title/employer/location. See [`recipes/qualify-against-icp.md`](recipes/qualify-against-icp.md).
- **Credit & approval gate** for any sizable paid run (pilot → approval → full). See SKILL.md.

## Hand-off
Sourced list → enrich `linkedin_profile` (work history, if thin) → qualify → **[`enriching.md`](enriching.md)**
(add email/phone/LinkedIn) → outreach.
