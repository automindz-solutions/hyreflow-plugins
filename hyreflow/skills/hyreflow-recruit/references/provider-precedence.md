# Provider precedence & waterfall order

How every recipe resolves **(a) which key pays for a tool** and **(b) which provider to use for a
substitutable capability**. Applies in Model A (the agent applies it at call time) and in the hosted
engine (the server resolves the key + meters credits).

## The rule
1. **Identify the capability** (e.g. "find a work email", "search people").
2. **Walk the provider order** for that capability: the client's override (`clients/<slug>/config.json`)
   → else the **house default** below.
3. **Resolve the key for each provider, in order:**
   - **client BYOK key present** (their env / vault) → use it — runs on *their* account/credits, costs hyreflow nothing.
   - else **hyreflow managed key**, where one exists → use it — metered as hyreflow credits. The sourcing
     and enrichment providers have one; the sequencers, recruiting CRMs and comms tools never do (see the
     BYOK-only exception below).
   - else **skip** this provider.
   - **BYOK-only exception — there is no managed key to fall back to.** Without the client's own key, the
     call cannot run: the first two groups below are refused with `no_key`, and the third simply isn't
     available. Three groups. For the first two, don't memorise the list — a method whose cost block says
     `unit: "byok"` (`hyreflow tools get <provider> <method>`) belongs to one of them. That check does
     **not** identify the third group, which prices as free and has to be recognised by name.
     - **Metered data providers** — Apollo, Shovels, BuiltWith, Apify, ZoomInfo. Each call spends the
       client's own vendor credits.
     - **The client's own sequencers, recruiting CRMs and meeting tools** — Instantly, Lemlist, HeyReach,
       Smartlead, SendKit, Recruit CRM, Recruiterflow, Loxo, Atlas, Fathom, Granola. These run on a flat plan the
       client already pays for, so a call costs nothing, but it only works once they've connected the
       account (dashboard **Integrations**, or `hyreflow byok set <provider> --api-key <key>`).
     - **Not self-serve yet:** ZoomInfo, Bullhorn, Vincere, Aircall, SourceWhale and JobAdder authenticate
       with OAuth or several secrets rather than a single key, so they can't be connected from the
       dashboard — treat one as unavailable unless the workspace has already been set up for it. Don't
       plan a run around one on the assumption it will be there.
4. **Call it.** On no-result / miss → fall to the next provider. Stop at the first good result.
5. **Single-source tools** (the client's ATS, their specific sequencer) **skip the order** — use *their*
   instance; **BYOK required** (you can't substitute someone's CRM).
6. **Hyreflow Natives** (`kind: "native"` — `hyreflow_native`, `layoffsignal`) **skip the waterfall entirely.** There is
   no third-party provider to fall through and **no BYOK path**, so a native is single-source (hyreflow),
   always on, and **always metered in hyreflow credits**. Treat it like an always-available house tool.
   Where a native covers the capability, it is the **default choice** — it needs no vendor account, can
   never be skipped for a missing key, and is priced as a house tool rather than carrying a vendor markup.
   Reach for a third-party provider when the native genuinely doesn't cover the ask (a filter or dataset
   only that vendor has), not by habit.

**Always prefer BYOK** — never burn hyreflow credits on a capability the client already has a key for.
BYOK availability can also *bias* the order: try the providers they hold keys for first.

> Note: key **presence is detected** (BYOK env/vault → else managed). Config does NOT store keys — it
> stores provider-order *preferences* + which single-source tools (ATS/sequencer) the client uses.

## House default orders (overridable per client)
| Capability | Default order |
|---|---|
| people_search | the `people_search` waterfall — house order lives in `reference/waterfalls.json`. **Default = SINGLE source** (just `aiark`); only walk further down the chain for **maximum coverage** or **after asking the customer** (see "Single-source by default" below). **BYOK reorders the chain** — a provider the client holds a key for jumps to the front (e.g. **BYOK Prospeo → query Prospeo first**, since it's free for them). NB: `lemlist`'s people *database/search* is allowed, and it runs only on the client's own connected lemlist account — without one that step is skipped and the chain moves on; Lemlist for **email enrichment is still forbidden** (activation only). The chain's **last two steps search the public web** and run only on a **company-scoped** query every people-DB missed — that's the small/new-company coverage case, and a row whose current company doesn't match the requested one is dropped. Rows flagged `verification_required` need the company/title confirmed on the profile. |
| **email type — pick by OUTREACH CONTEXT** | **candidate acquisition → `personal_email` + LinkedIn (NEVER work email); BD/selling to companies → `email_enrichment` (work)** |
| developer_sourcing (IT) | **Pick the primary by role type.** Code-writing roles (SWE, data/ML, backend/frontend): **github** leads — free, ground-truth (skill proof + personal email via commit-harvest + website/socials + impact-tier stars) — **with the people-DB leg (aiark→…) run in parallel to its own `1.5×N` row target**, since GitHub only covers OSS-active devs. Infra/sysadmin/network/IT-support: **skip GitHub, people-DBs are the primary leg** (title + skills + location). → merge (GitHub wins a dedup tie) → optional Firecrawl+AI on personal site for deep context → qualify. See [`recipes/it-sourcing.md`](../recipes/it-sourcing.md). Candidate channel: personal email + LinkedIn (discard GitHub-harvested employer emails). |
| construction/trades sourcing | **shovels** is the PRIMARY candidate DB for this vertical: `search_contractors` (by trade/metro/hiring-signal) → `get_contractor_employees` returns named staff with `job_title`/`seniority`/`department` + **personal `email` + `linkedin_url` + phone** (candidate-channel-ready, no enrichment). Fallback to general people-DBs/Exa when a contractor has no employee records (solo operators). 🔴 EEO: never filter on gender/age/marital/children/income fields. |
| email_enrichment (work) | the `email_enrichment` waterfall — house order lives in `reference/waterfalls.json`, never restate it here. |
| personal_email | the `personal_email` waterfall — house order lives in `reference/waterfalls.json`. Providers: fullenrich (`contact.personal_emails`), leadmagic (`personal_email_finder`), wiza (`enrichment_level=partial` + `email_options.accept_personal:true`; also takes Sales Nav/Recruiter URLs) + GitHub commit-email for engineers (free). ⚠️ **prospeo / aiark / lusha = WORK email only — never for personal/candidate workflows.** An address on the person's own company domain is not a personal email: whichever provider returns one, the row records `outcome: "corporate_domain"`, is charged **0**, and the chain keeps walking — so a row that finds no personal email costs nothing. |
| linkedin_profile (employment history) | the `linkedin_profile` waterfall — house order lives in `reference/waterfalls.json`. One canonical capability: `hyreflow tools execute linkedin_profile --payload '{"linkedin_url":"…"}'`. Returns a normalized profile with `experience[]` (company/title/start/end/is_current, newest first) whichever provider answered, so past-employer checks ("has worked at a startup") never need a hand-picked scraper actor. First hit wins, only the hitting step is metered. ⚠️ **Do NOT hand-roll a raw Apify actor for job history** — Apify is BYOK-only and its actor spend is invisible to hyreflow credits, the spend cap and the approval gate. |
| phone_enrichment | wiza(`phone`/`full`, mobiles) → prospeo(enrich_mobile) → bettercontact → fullenrich → leadmagic → lusha |
| email_validation | enrichley → leadmagic(email_validation) |
| company_search (firmographic / TAM) | **aiark `company_search` · apollo · prospeo `search_company` · lusha** (richest firmographics — industry/keywords/size/geo/revenue/**tech inline**/NAICS/type; aiark also `retailSize`/`metric`) → zoominfo → exa. **TAM membership = firmographic/ICP fit, NOT current hiring** — theirstack/predictleads hiring & intent signals are *timing triggers*, never TAM filters. Technographics are inline in aiark/apollo/prospeo/lusha/theirstack (builtwith = who-uses-X breadth). See [`recipes/build-tam.md`](../recipes/build-tam.md). |
| company_lookalikes | **prospeo** (`enrich_company`→`company_id`→`search_company` `company_lookalike`, tiers T1/T2/T3) · **zoominfo** `company_lookalikes` · **lusha** `company_lookalikes` · **predictleads** `similar_companies` · **exa** `find_similar` (semantic, from a URL). ⚠️ **Resolve + VERIFY the seed first** (exact domain / LinkedIn match — bare shared-SaaS domains mis-resolve); see [`provider-playbooks/prospeo.md`](../provider-playbooks/prospeo.md) lookalike flow. |
| hiring/intent signals | **`hyreflow_native` job scrapes are the DEFAULT for "who is hiring for X" / "find open roles"** — first-party, no vendor account, always available, **0.05 credits per matched job** (pay-on-match) vs theirstack's 0.9, async launch→poll: `career_pages` (a named company's own site + ATS), `linkedin_jobs` / `indeed_jobs` (title + location across companies), `arbeitsagentur_jobs` (**the German federal job board — the default source for a Germany-scoped hiring query**); see [`provider-playbooks/hyreflow_native.md`](../provider-playbooks/hyreflow_native.md) → then **theirstack** when the query needs *its* filters rather than raw postings (tech-stack / keyword-slug-filtered job or company search, technographics, buying intent) → then predictleads (job openings + tech detections) → jobs scrape: apify (**BYOK-only** — needs the client's own key) · pharma: clinicaltrials · construction: shovels · **layoffs/RIF: layoffsignal (native)** |
| funding discovery (Series A etc.) | **predictleads (discover_financing_events — by round type + recency)** → zoominfo scoops → leadmagic company_funding (enrich-only) → exa/serper (news) |
| sequencer | usually single-source (use the client's); fallback email: instantly→smartlead→sendkit→lemlist · LinkedIn: heyreach→lemlist · recruiting: sourcewhale. SendKit is the pick when the play needs a deliverability check (mailbox health/warmup) before sending. ⚠️ Sequencers are **activation only — never enrichment** (don't use Lemlist findEmail/linkedinEnrichment etc.; enrich upstream). |
| ATS | single-source — the client's: recruit-crm \| loxo \| vincere \| recruiterflow \| atlas \| bullhorn \| spott \| jobadder |

## Single-source by default — multi-source only on demand
For substitutable discovery/enrichment (`people_search`, `email_enrichment`), **default to ONE source**
(the top of the waterfall). Do **not** automatically fan out across the whole chain — every extra
provider costs extra credits and usually adds little for a well-specified query.

Walk further down the chain **only** when:
- the customer **explicitly needs maximum coverage** ("get me everyone you can"), **or**
- you **asked first** — at scope/approval time, prompt: *"Query just 1–2 databases (cheaper), or fan out
  across all sources for maximum coverage?"*

The waterfall also doubles as a **per-row fallback on a miss**: single-source first; if it returns
nothing / no email for a given row, fall to the next provider **for that row only** — that is not the
same as a blanket multi-source sweep of the whole list.

## Per-client config
Lives **outside** this skill (client data), e.g. `clients/<slug>/config.json` + `ICP.md`. Shape:
`reference/client-config.example.json`. A recipe reads it to get the order overrides + the client's
ATS/sequencer; everything else falls back to the house defaults above.
