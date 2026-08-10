# Recipe: CV → fitting jobs → hiring manager (spec-out / MPC)

**The inverse of `jd-to-shortlist`.** Input is a *candidate* (CV or ATS slug); output is a ranked list
of **companies in the candidate's region with live open roles that fit them**, each with the **hiring
manager to pitch** (name · title · LinkedIn · work email). This is **candidate-led BD** ("spec-out" /
Most-Placeable-Candidate): you lead with talent and proactively pitch the person to companies that are
visibly hiring that profile.

> **What's next + why:** this is the **MPC / spec-out** branch of the funnel (BD on a candidate). See
> [`../recruiter-craft.md`](../recruiter-craft.md) §B for the branch and its work-email channel rule.

> Ported from the proven `SynergyB/synergy-tools` `mpc` skill (German recruitment client). Two changes
> vs. that skill: (1) hiring-manager discovery uses **our `people_search` + email-enrichment waterfall**
> instead of Prospeo; (2) it's generalised beyond finance/accounting to any function.

## Capability chain
```
CV/slug → PARSE (AI, multimodal fallback) → SEARCH JOBS (3 Apify actors ‖) → NORMALIZE+FILTER
        → MATCH/SCORE each job ↔ CV (AI 0-10) → FIND HIRING MANAGER (company-scoped people_search,
          size-adaptive title hierarchy + reporting-line-first) → ENRICH work email (waterfall)
        → output: ranked target companies + job + fit + hiring manager + spec-out outreach message
```

## Channel (hard rule)
Hiring-manager outreach is **BD toward the company** → **WORK email** (email_enrichment waterfall).
The candidate is *yours* (consented) — no candidate-channel concern. See
[`enriching.md`](../enriching.md).

## Output dir (set up first)
`clients/<client-slug>/runs/cv-to-jobs-<candidate-slug>/` (or `<cwd>/hyreflow-runs/...` ad-hoc).
Candidate slug: lowercase first+last, umlauts folded (ä→ae ö→oe ü→ue ß→ss), no spaces. Never write to
`%TEMP%` or inside the skill. Outputs UTF-8 (BOM for Excel).

---

## STEP 1 — Input & CV extraction

**Modes:** (a) CV file (`.pdf`) → copy to run dir as `cv.pdf`; (b) ATS slug → pull candidate record +
download résumé (`recruit-crm`/`bullhorn` candidate get) → `cv.pdf` + `candidate_meta.json`.

**Parse** → canonical candidate profile:
- `titles_current` (1), `titles_past` (≤5, newest first), `skills_top` (≤10 **hard** skills, no soft),
  `location {city, plz_if_visible, country}`, `years_experience` (int estimate), **`function`**
  (finance / engineering / sales / ops / … — drives the hiring-manager title family in Step 5).
- **`stations[]`** — for each career station a short **2–3 line summary**: `{employer, role, period,
  summary}`, where `summary` describes what they actually did/owned there, grounded in the CV. These
  per-station blurbs feed the spec-out narrative and sharpen the job↔CV match in Step 5.
- **Text-layer check:** if extracted text `< ~200 chars` (Canva exports & scanned PDFs have no text
  layer) → **multimodal fallback: read the PDF as an image** (your harness's file/vision read, or
  `hyreflow_agent` vision) and extract fields from the image. Never abort on a no-text PDF.

→ save `cv-analysis.json`. Show the profile, confirm before searching.

## STEP 2 — Search params (the German-market knobs)

- `target_titles[]` — default `titles_current + titles_past`, cap 5.
- **Region + radius** — default `location.city` from CV; e.g. `"München, 30km"`. Apply the
  **location-expansion rule** (`finding-companies-and-contacts.md`): a city implies its commute belt; an explicit
  radius → enumerate the cities in it. Each board consumes this differently (below).
- `plz` — 5-digit postal code (StepStone needs it in the URL path).
- `city_en` — LinkedIn needs the English city name. Hardcoded map for the top German cities:
  `München→Munich, Köln→Cologne, Nürnberg→Nuremberg, Hannover→Hanover, Wien→Vienna, Zürich→Zurich`
  (others pass through).
- `size_buckets` (optional, soft-rank). **Hard floor: drop companies < 20 employees** *only when size is
  known* (StepStone never has it → keep). One bucket → LinkedIn hard-filter; multiple/empty → soft-rank only.

## STEP 3 — Job search: 3 Apify actors in parallel (German trio)

> Why three: LinkedIn + **StepStone** (essential for DACH) + Indeed together cover the German market a
> single source misses. Run all three concurrently (`apify.run_actor`), then merge.

**LinkedIn** — actor `vIGxjRrHqDTPuE6M4`:
```json
{ "titleSearch": ["<t1>","<t2>"], "locationSearch": ["Munich","München","Bavaria"],
  "timeRange": "7d", "limit": 50, "removeAgency": false, "includeAi": true }
```
- `locationSearch` is **phrase-match** → supply several variants **+ the region as fallback** (LinkedIn
  mislabels many city jobs, e.g. `München, Brandenburg`; a single city variant often returns 0).
- `removeAgency: false` — the server filter is too aggressive; we strip agencies ourselves (Step 4).
- One size bucket → add `organizationEmployeesGte` / `organizationEmployeesLte`.

**StepStone** — actor `pIVhuvHZkW2Llfjrr` (pure-HTTP vs. the unified-resultlist JSON API, ~$1/1k,
Residential proxy). Build the URL from titles + plz + radius:
```
slug(title): lowercase, ä→ae ö→oe ü→ue ß→ss, drop (...), non-alnum→'-'
url = https://www.stepstone.de/jobs/<slug1>-or-<slug2>/in-<plz>?radius=<km>
      &searchOrigin=Resultlist_top-search&q=(<T1> OR <T2>)%20
```
```json
{ "startUrls": [{ "url": "<built_url>" }], "includeRelatedJobs": false, "postedWithin": "7",
  "maxItems": 100, "proxy": { "useApifyProxy": true, "apifyProxyGroups": ["RESIDENTIAL"] } }
```
- **Do not** use the old Puppeteer actor `o6JjyowF7532cPwan` — blocked by Cloudflare/HTTP-2 bot detection.
  `pIVhuvHZkW2Llfjrr` bypasses it via residential proxy + JSON API.

**Indeed** — actor `MXLpngmVpE8WTESQr` (takes structured params, no URL build):
```json
{ "query": "(<t1> OR <t2>)", "country": "de", "location": "<city_de>", "maxItems": 100, "fromDays": "14" }
```
- `country` must be **lowercase ISO-2** (`"de"`); `fromDays` must be a **string** (`"14"`).

**Keep limits modest.** Start at `limit`/`maxItems` ≈ **50–100** per actor — that's plenty of fresh
postings for one candidate's region; scale only if coverage comes back thin. Apify bills per result, so
modest limits keep the run cheap — that spend is on the client's own Apify account (Apify is BYOK-only;
Hyreflow charges 0 credits). *(No separate payload-approval step — this recipe just runs.)*

## STEP 4 — Normalize + filter

- **Dedup** across the 3 sources (company + title + location key).
- **Strip agencies:** denylist + LinkedIn agency flag (we keep `removeAgency:false`, so filter here).
- **Size floor:** drop `< 20` employees when known; keep when unknown.
- **Location verify:** confirm each job sits in the candidate's region / commute belt (geocode).
- **Size soft-rank:** nudge toward preferred buckets (don't hard-drop unless exactly one bucket).

## STEP 5 — Match & score each job ↔ CV  (inverse `/qualify`, 0-10)

Same AI-scoring brick as `jd-to-shortlist`, **oriented one-candidate × many-jobs**: for each surviving
posting, score *how well this CV fits that role* 0-10 + the gaps via `prompts.json → "Score job against CV
(0-10)"` (the inverse of "Score candidate against job (0-10)"). Run it with `POST /tools/hyreflow_agent/infer`
per job (or Model A — free, interactive) — **not** the `/qualify` endpoint, which is *candidates × one job*,
the opposite orientation. Rank; keep the top fits for Step 6.

## STEP 6 — Find the hiring manager  (Prospeo → **our stack**)

For each top-fit company, company-scoped **`people_search`** (the scoping we built — pass name + domain +
company_linkedin so each provider scopes correctly; `finding-companies-and-contacts.md`), with a **size-adaptive
title hierarchy** (ported from mpc's `prospeo-search-strategy`, generalised by `function`).

> **Size buckets are per-client config, not fixed.** Each hyreflow customer defines their own
> `size_buckets` (the same ones used for the Step-2 soft-rank) and which seniority owns the hire in each
> bucket — read them from the client config (alongside `provider_order`/`ICP.md`), don't hardcode. The
> table below is the **default** shape (the mpc client's `100 / 500` thresholds shown as illustration);
> override per client.

| Company size (client buckets) | Who owns the hire → search titles |
|---|---|
| **unknown** | Founder/GF/CEO **+** `<function>`-head **+** HR-head (widest net) |
| **small** *(default < 100)* | Founder/CEO/**Geschäftsführer** **+** `<function>`-head *(small co → talk to the GF)* |
| **mid** *(default 100–500)* | HR-head **+** `<function>`-head **+** GF fallback |
| **large** *(default > 500)* | HR-head **+** `<function>`-head |

- `<function>`-head is derived from the candidate's `function`: finance→"Head of Finance / Leiter
  Finanzen / CFO"; engineering→"Head of Engineering / CTO / IT-Leiter"; sales→"Head of Sales /
  Vertriebsleiter"; etc. (DE + EN title variants — the mpc `TITLE_FAMILIES` are the finance seed list.)
- **Reporting-line-first** (`finding-companies-and-contacts.md`): if a posting names the reporting line / interview
  panel, find that person directly (`exa` + verify) before falling back to the title hierarchy.
- Pick the best match (most senior in-function at the scoped company); then **email_enrichment waterfall**
  for the **work email** (BD channel) — `prospeo→bettercontact→fullenrich→…` per `provider-precedence`.

## STEP 7 — Output: the spec-out outreach message

Per candidate: a ranked list of **target companies → open job → fit + gaps → hiring manager
(name · title · LinkedIn · work email)**, and for each target a ready **spec-out outreach message** —
an anonymised candidate pitch to the hiring manager (work email / BD channel): the candidate stays
nameless ("a strong `<role>` with `<1-2 differentiators>`"), the message ties them to *that* company's
open role and asks for a short call. Generate it with `prompts.json → "Spec-out sequence (anonymised
candidate to hiring manager)"` — a 2-touch sequence (spec-out email 1 + follow-up email 2) returned as
`{subject, email1, email2}`, context-tied to that company's open role; match the client's brand voice.
Identity is revealed only when the company engages. **No frontsheet/PDF, no deploy, no CRM write** — the
deliverable is the message.

---

## Gates & caveats (honest)
- **Public-postings-only:** the Apify trio captures *advertised* roles; agency-run / unposted hires are
  invisible. Add an internal leg (your own ATS open mandates) if you also want to place on live jobs first.
- **Apify is BYOK-only:** the client must have their own Apify token connected in Integrations, or all 3
  actors return `no_key` and this recipe has no job source. Their account is billed per result
  (StepStone ~$1/1k) → keep `limit`/`maxItems` modest (50–100). Hyreflow charges 0 credits.
- **`removeAgency:false`** on LinkedIn is deliberate — we filter agencies in Step 4, not server-side.
- **Hiring-manager coverage:** excellent when the posting names the reporting line or the company is
  well-indexed; thin at tiny firms (the size hierarchy's "< 100 → GF" branch is the fallback for that).
- **EEO / GDPR:** score on role/skills/experience only — never gender/age/etc. Hiring-manager work email
  is BD-consented context; candidate stays anonymised until the company engages.

## New prompts to add (`prompts.json`)
- `parse-cv` — CV text/image → canonical candidate profile (titles, skills, location, years, function).
- `score-job-vs-cv` — inverse of `score-candidate-vs-job`: one candidate × one job → 0-10 + gaps.

## Reusable asset
The **German job-board trio** (LinkedIn `vIGxjRrHqDTPuE6M4` + StepStone `pIVhuvHZkW2Llfjrr` + Indeed
`MXLpngmVpE8WTESQr`, with the payload quirks above) is reusable for *any* DACH sourcing — consider
promoting it into `provider-playbooks/apify.md` as the canonical German job-search actor set.
