# Recipe: Multi-strategy sourcing (5 angles — max coverage + talent map)

**The wide-coverage sourcing play.** One brief → source the same role from **five complementary angles**
(structured + semantic merge, tiered competitor talent map, lookalike expansion, passive-intent mining),
merge into one deduped pool, qualify, then spend signal/enrich budget on survivors only. A pattern the
agent composes from existing capabilities — **no new engine primitives**.

> **Key rule:** every angle is **recall**; the qualify step is **precision**. Run the cheap discovery
> angles first, **merge + qualify for free**, and only THEN spend per-row credits (signal scans, enrich)
> on the candidates that survived. Never pay to scan or enrich a `no_fit`.

> **Not this recipe?** For a plain cross-DB structured merge (one title set across AI Ark · Lemlist ·
> Prospeo, dedup + qualify — no semantic/competitor/intent angles) use
> [`multi-source-candidate-search.md`](multi-source-candidate-search.md). This recipe is the superset:
> use it when the ask is "leave no stone unturned", a **talent / market map**, or "find the passive
> ones the structured filters miss".

## Capability chain
```
Brief → PARSE (AI) → [ STRUCTURED people_search  +  SEMANTIC exa_search ]  (angle 1, parallel)
      → COMPETITOR talent map (tiered, angle 2) → LOOKALIKE expansion (angle 3)
      → PASSIVE-INTENT mine (aiark OPEN_TO_WORK + pool signals, angle 4)
      → MERGE + dedup (linkedin_url) + RANK → ENRICH PROFILES (work history) → QUALIFY (AI, free)  ← the pay gate
      → SIGNAL scan (exa, survivors only) → ENRICH (personal email + LinkedIn) → DELIVER (+ blind MPC one-pager)
```
Docs this leans on: [`finding-companies-and-contacts.md`](../finding-companies-and-contacts.md) (search /
company-scoping / OPEN_TO_WORK), [`enriching-and-researching.md`](../enriching-and-researching.md)
(contact), [`writing-outreach.md`](../writing-outreach.md) (DM personalization),
[`provider-playbooks/exa.md`](../provider-playbooks/exa.md),
[`provider-playbooks/aiark.md`](../provider-playbooks/aiark.md), `prompts.json`.

## Inputs
- **Brief** (JD text or a structured ask, any language). Optional: target count N (default 10),
  location override, **strategy mix** (default: all angles; drop any the brief doesn't warrant),
  competitor list (else discovered), `signal_scan` cap (default top-N tier_1/tier_2 only).

## Steps

**0 — PARSE the brief → canonical `PeopleQuery`** *(AI step — free on the host agent)*
- Extract `{ titles[] (role + EN/DE variants), skills[] (must-haves), certifications[],
  min_experience_years, locations[], seniority, keywords[] }` **plus** the hiring company
  `{name, domain, category}`. Same schema as [`jd-to-shortlist.md`](jd-to-shortlist.md) step 1.
- **Enum pre-validation (free, prevents silent 0-results):** before any paid pull, confirm enum-ish
  filters resolve — Prospeo location must be a canonical value from `search_suggestions`
  (a ZONE covers a metro radius in one value); AI Ark seniority/badge must be a real enum from the
  cached spec (see [`provider-playbooks/aiark.md`](../provider-playbooks/aiark.md)). An invalid enum is
  **silently ignored or returns 0** — validate, don't guess.

**1 — ANGLE 1 · Hybrid funnel (structured ∥ semantic discovery)** *(cheap; count-/numResults-gated)*
- **Structured leg** — the `people_search` waterfall with the JD filters. **Count-peek `size:1` first**
  to size the pool, then pull. Tag `_source = structured`.
  → `hyreflow tools execute people_search --payload '{...JD filters, "limit":~1.4×N}'`
- **Semantic leg** — Exa neural people search on a natural-language ideal-candidate description (catches
  profiles whose titles/company data don't match structured filters). **Small `numResults` pilot first.**
  Tag `_source = semantic`.
  → `hyreflow tools execute exa_search --payload '{"query":"<NL ideal candidate>","category":"people","numResults":10,"type":"neural"}'`
  (resolve each result's LinkedIn URL from the hit; `exa_contents` only if you need the page text.)
- **Merge** the two legs, dedup by `linkedin_url` (the engine's dedup key); a row may carry both sources.

**2 — ANGLE 2 · Competitor talent map (tiered)** *(generalizes the jd-to-shortlist competitor leg)*
- **Discover** competitors via `exa_answer` (NOT `find_similar` — that returns directories). Use the
  **"Find & verify competitors"** prompt for the domain-verified version.
  → `hyreflow tools execute exa_answer --payload '{"query":"direct competitors of <company> (<domain>) in <category>","text":true}'`
- **Tier** the verified competitors A/B/C (A = closest head-to-head). For each, run `people_search`
  **company-scoped** (`company_domains`/`company_names`) with the JD filters, **count-before-pay** per
  domain. Tag `_source = competitor:<domain>` and record a **tier weight** (A>B>C) for ranking.
- **Bench-concentration (agent post-process, free):** count hits per company **across all angles**; any
  company with **≥4 hits = a raid-target**. The tier-by-company table doubles as a sellable **Market Map**
  deliverable. *(Phase-1 note: this is computed in-session by the agent, not an engine output yet.)*

**3 — ANGLE 3 · Lookalike expansion** *(seed-driven; reuses people_search + exa_search)*
- Take the **top-5** from angles 1–2 as seeds. Model-A (free) extracts feature vectors: current + prior
  `company_names`, headline keywords, tenure pattern.
- Re-run `people_search` with `company_names` = seeds' + competitors' employers, AND feature-driven
  `exa_search` queries (the headline-keyword phrasing). Catches non-standard titles / inactive profiles.
  Tag `_source = lookalike`. *(Phase-1 note: composed here from existing tools; a first-class `lookalike`
  capability is deferred to Phase 3.)*

**4 — ANGLE 4 · Passive-intent mining** *(aiark badge + pool signals)*
- **Open-to-work (flat aiark advanced path):** AI Ark is the only DB with the badge filter. Drop to the
  flat provider call with the badge **paired with title/location** (badge alone ≈ 24M pool):
  → `hyreflow tools execute aiark people_search --payload '{"contact":{"profileBadge":{"any":{"include":["OPEN_TO_WORK"]}},"experience":{"current":{"title":{"any":{"include":{"mode":"SMART","content":["<title>"]}}}}},"location":{"any":{"include":["<city>"]}}},"page":0,"size":25}'`
  The body is `{account, contact, lists, page, size}` (**`page` 0-based + `size`≤100 are required**) — no
  `filters` wrapper. `profileBadge.include` is a **bare enum array** (`["OPEN_TO_WORK"]`); `title` is a
  **text filter** (`{mode,content[]}` object); `location` is a **bare array**. See
  [`provider-playbooks/aiark.md`](../provider-playbooks/aiark.md) "Filter structure". Tag
  `_source = open_to_work`.
- **Pool-mine (free, agent):** scan the already-sourced pool for intent patterns (former / "a.D." /
  recent tenure-end in the headline/positions) → classify **HOT / WARM / COLD** using the
  **"Detect open-to-work / job-change signals"** prompt (profile-derived). Pool-mining is the source of
  truth — there is **no `person_job_change` tool**; do not call one.

**5 — MERGE + RANK** *(free)*
- Dedup the full pool by `linkedin_url` (fallback `name|company`), **union the `_source` tags** per
  person (a candidate found by 3 angles ranks higher). Preserve lineage columns.
- Rank by a **brief-customized rubric** with the competitor **tier weight** and an intent bump
  (HOT > WARM). Use **"Score candidate against job (0-10)"** for a transparent per-candidate breakdown.

**6a — ENRICH PROFILES (work history) — the input the gate scores on** *(metered per hit; the cheapest
per-row step, and the one that makes the gate mean something)*
- `hyreflow tools execute linkedin_profile --payload '{"linkedin_url":"…"}'` per candidate (bulk:
  `POST /enrich/linkedin_profile {"rows":[…]}`) → a normalized `profile` with
  `experience[{company, title, start, end, is_current, duration_months?, description?}]`, newest first.
  A row that comes back without employment history is a miss and costs nothing.
- **Cap it** to the ranked pool you actually intend to shortlist (~1.4×N), and skip rows that already carry
  history (CRM/ATS records, `atlas.get_person`). `about`/`skills`/`certifications` depend on which provider
  answered — often empty, so read an absence as unknown, not as a gap.

**6b — QUALIFY against the brief — THE PAY GATE** *(AI step, free on the host agent)*
- Score each candidate **on the dated work history from 6a**, not on the current title → `tier_1 | tier_2 |
  no_fit`; **drop `no_fit`**. Use the **"Qualify candidate against role"** prompt, or the batch `/qualify`
  endpoint for many×one:
  → `hyreflow qualify --job @brief.md --candidates @pool.json [--min-score N]`
  `/qualify` reports `qualify.basis` (`work_history` | `title_only`) per candidate and **refuses a batch in
  which no row carries history** (422 `no_work_history`) — run 6a, or pass `allow_thin_profiles: true` to
  accept a title-only ranking knowingly.
- **Everything below this line spends the EXPENSIVE per-row credits** (signal scans, contact reveals) — so it
  runs on survivors only.

**7 — ANGLE 2-signal · proof-of-work scan** *(metered; survivors only; capped)*
- For the top-N `tier_1`/`tier_2` only (honor the `signal_scan` cap), run an Exa proof-of-work scan
  (talks, podcasts, posts, webinars). **Boost** candidates with a surfaced artifact and **carry the
  artifact** into the DM mandate below.
  → `hyreflow tools execute exa_search --payload '{"query":"<name> <company> talk OR podcast OR post","category":"people","numResults":5}'`
  (`exa_contents` to pull the page text of a promising hit.)

**8 — ENRICH (candidate channel)** *(`enriching-and-researching.md`; gated)*
- **Personal email + LinkedIn — NEVER work email** (candidates). `personal_email` waterfall
  (order in `reference/waterfalls.json`), first-hit, verify deliverability.
  → `hyreflow enrich --input <ds_id|csv> --with '{"alias":"personal_email","tool":"personal_email","payload":{...}}'`

**9 — DELIVER**
- A ranked, brief-qualified shortlist CSV (lineage `_source` tags + tier + intent + artifact link).
- **Optional blind MPC one-pager** — an anonymized candidate spotlight (redact name/contact; keep
  skills, headline, proof-of-work artifact, fit summary) the recruiter can send. Render with the
  **"Spec-out sequence (anonymised candidate to hiring manager)"** prompt. *(Phase-1: agent-rendered
  markdown, not an engine output yet — Phase 3.)*
- **DM-personalization mandate:** every outreach line references a **real artifact** (the proof-of-work
  from step 7, a shared company, a specific project) — **never generic**. Use the **"Candidate outreach
  first line (LinkedIn)"** prompt.

## Gates
- **Count-before-pay** (structured / company-scoped legs) and **small-`numResults` pilot** (Exa legs)
  before any depth.
- **Pilot → approval → full** for the paid full run (see SKILL.md credit-and-approval gate).
- **Qualify before per-row spend** — signal scans (step 7) and enrich (step 8) run on survivors only.
- **Candidate channel** = personal email + LinkedIn (never work email). **EEO:** never filter on
  age/gender/marital status/etc. — role/skill/location/intent only.
- **Over-provision ~1.4×N**, single-source-default.

## Cost shape
| Step | Metered |
|---|---|
| 0 parse + enum validate | AI tokens (free); `search_suggestions` free |
| 1 structured leg | aiark ~0.5/result (first source that fills) — count-peek free |
| 1 semantic leg / 2 competitor discover / 3 lookalike exa / 7 signal | Exa per call (gate with small `numResults`) |
| 2 competitor legs | aiark ~0.5/result per competitor (count-before-pay) |
| 4 open-to-work | aiark ~0.5/result |
| 5 merge + rank / 6b qualify | AI tokens (free on the host agent) |
| 6a profile enrich | per-hit (`linkedin_profile` providers; a miss costs 0) — cap to the ranked pool |
| 8 enrich | per-hit (personal-email providers) |
Free: dedup, ranking, bench-concentration table, intent classification, the channel/EEO rules.

## Output
A **ranked, brief-qualified shortlist** drawn from five angles — competitor- and intent-boosted first,
lookalike/semantic profiles filling the rest — each with LinkedIn + personal email and a proof-of-work
artifact, ready for a personalized candidate sequence. Plus an optional **competitor Market Map**
(bench-concentration / raid-targets) and a **blind MPC one-pager** per spotlight candidate.

## Notes from live runs
- **Run the cheap angles, enrich the profiles, qualify, THEN spend.** The expensive per-row work (signal
  scans, contact enrich) is step 7–8 on purpose — surviving the qualify gate is what earns it.
- **A title snapshot ranks the wrong people.** Sourcing output shows the current role only, so recent joiners
  at strong employers float up and specialists behind a generic title sink. The dated history from 6a is what
  makes tier_1 mean tier_1.
- **Exa tool names are `exa_search` / `exa_contents` / `exa_answer`** (underscore), and `category:"people"`
  for candidates — `exa search` / `get_contents` are not callable names. Validate with
  `hyreflow tools get exa_search`.
- **OPEN_TO_WORK rides the canonical `people_search` waterfall** — pass `profile_badges:["OPEN_TO_WORK"]`
  (it maps to `contact.profileBadge` and pins the chain to aiark, the only DB with this signal). Pair it
  with title/location or you'll pull the ~24M global pool.
- **Phase-1 honesty:** the semantic merge/dedup is **agent-side** (the engine doesn't own an Exa sourcing
  arm yet), and bench-concentration + the blind MPC one-pager are **agent-rendered**, not engine outputs.
  Those become first-class in later phases — until then this recipe gets you the coverage by composition.
- Small/niche competitors may return 0 people (thin DB coverage) — the A-tier and the general structured
  leg backstop.
