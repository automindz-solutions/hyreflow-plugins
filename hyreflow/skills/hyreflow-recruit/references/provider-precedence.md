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
   - else **hyreflow managed key** → use it — metered as hyreflow credits.
   - else **skip** this provider.
   - **Apollo exception:** Apollo is BYOK-only for user workspaces. If the workspace has no Apollo BYOK key,
     skip Apollo with `no_key`; do not fall back to a Hyreflow-managed Apollo key.
4. **Call it.** On no-result / miss → fall to the next provider. Stop at the first good result.
5. **Single-source tools** (the client's ATS, their specific sequencer) **skip the order** — use *their*
   instance; **BYOK required** (you can't substitute someone's CRM).
6. **Hyreflow Natives** (`kind: "native"` — e.g. `layoffsignal`) **skip the waterfall entirely.** There is
   no third-party provider to fall through and **no BYOK path**, so a native is single-source (hyreflow),
   always on, and **always metered in hyreflow credits**. Treat it like an always-available house tool.

**Always prefer BYOK** — never burn hyreflow credits on a capability the client already has a key for.
BYOK availability can also *bias* the order: try the providers they hold keys for first.

> Note: key **presence is detected** (BYOK env/vault → else managed). Config does NOT store keys — it
> stores provider-order *preferences* + which single-source tools (ATS/sequencer) the client uses.

## House default orders (overridable per client)
| Capability | Default order |
|---|---|
| people_search | **aiark → prospeo → lemlist (DB) → apollo** → zoominfo. **Default = SINGLE source** (just `aiark`); only walk further down the chain for **maximum coverage** or **after asking the customer** (see "Single-source by default" below). **BYOK reorders the chain** — a provider the client holds a key for jumps to the front (e.g. **BYOK Prospeo → query Prospeo first**, since it's free for them). NB: `lemlist (DB)` = its people *database/search*, which is allowed; Lemlist for **email enrichment is still forbidden** (activation only). |
| **email type — pick by OUTREACH CONTEXT** | **candidate acquisition → `personal_email` + LinkedIn (NEVER work email); BD/selling to companies → `email_enrichment` (work)** |
| developer_sourcing (IT) | **github (PRIMARY — free, ground-truth: skill proof + personal email via commit-harvest + website/socials + impact-tier stars) + people-DBs in parallel for breadth (aiark→…)** → merge (GitHub prioritised) → optional Firecrawl+AI on personal site for deep context → qualify. See [`recipes/it-sourcing.md`](../recipes/it-sourcing.md). Candidate channel: personal email + LinkedIn (discard GitHub-harvested employer emails). |
| construction/trades sourcing | **shovels** is the PRIMARY candidate DB for this vertical: `search_contractors` (by trade/metro/hiring-signal) → `get_contractor_employees` returns named staff with `job_title`/`seniority`/`department` + **personal `email` + `linkedin_url` + phone** (candidate-channel-ready, no enrichment). Fallback to general people-DBs/Exa when a contractor has no employee records (solo operators). 🔴 EEO: never filter on gender/age/marital/children/income fields. |
| email_enrichment (work) | **prospeo → bettercontact → fullenrich** → lusha → wiza (→ leadmagic → icypeas as last resort). **Core three = `prospeo → bettercontact → fullenrich`** — that's the order that matters; the rest are tail fallbacks. |
| personal_email | **fullenrich** (`contact.personal_emails`) → **leadmagic** (`personal_email_finder`) → **wiza** (`enrichment_level=partial` + `email_options.accept_personal:true`; also takes Sales Nav/Recruiter URLs) — the personal-email providers in our stack (COO-confirmed; Wiza pending live confirm) + GitHub commit-email for engineers (free). ⚠️ **prospeo / aiark / bettercontact / lusha = WORK email only — never for personal/candidate workflows.** |
| phone_enrichment | wiza(`phone`/`full`, mobiles) → prospeo(enrich_mobile) → bettercontact → fullenrich → leadmagic → lusha |
| email_validation | enrichley → leadmagic(email_validation) |
| company_search (firmographic / TAM) | **aiark `company_search` · apollo · prospeo `search_company` · lusha** (richest firmographics — industry/keywords/size/geo/revenue/**tech inline**/NAICS/type; aiark also `retailSize`/`metric`) → zoominfo → exa. **TAM membership = firmographic/ICP fit, NOT current hiring** — theirstack/predictleads hiring & intent signals are *timing triggers*, never TAM filters. Technographics are inline in aiark/apollo/prospeo/lusha/theirstack (builtwith = who-uses-X breadth). See [`recipes/build-tam.md`](../recipes/build-tam.md). |
| company_lookalikes | **prospeo** (`enrich_company`→`company_id`→`search_company` `company_lookalike`, tiers T1/T2/T3) · **zoominfo** `company_lookalikes` · **lusha** `company_lookalikes` · **predictleads** `similar_companies` · **exa** `find_similar` (semantic, from a URL). ⚠️ **Resolve + VERIFY the seed first** (exact domain / LinkedIn match — bare shared-SaaS domains mis-resolve); see [`provider-playbooks/prospeo.md`](../provider-playbooks/prospeo.md) lookalike flow. |
| hiring/intent signals | theirstack · predictleads (job openings) · jobs scrape: apify · pharma: clinicaltrials · construction: shovels · **layoffs/RIF: layoffsignal (native)** |
| funding discovery (Series A etc.) | **predictleads (discover_financing_events — by round type + recency)** → zoominfo scoops → leadmagic company_funding (enrich-only) → exa/serper (news) |
| sequencer | usually single-source (use the client's); fallback email: instantly→smartlead→lemlist · LinkedIn: heyreach→lemlist · recruiting: sourcewhale. ⚠️ Sequencers are **activation only — never enrichment** (don't use Lemlist findEmail/linkedinEnrichment etc.; enrich upstream). |
| ATS | single-source — the client's: recruit-crm \| loxo \| vincere \| recruiterflow \| bullhorn |

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
