# Recipe: JD → Shortlist (competitor-poach + promotion-ready talent)

**The most-requested recruiter play.** Paste a job description → extract searchable filters → source candidates
(**general search + prioritized competitor profiles + a promotion lane**) → enrich the profiles (work history) →
qualify against the JD → assess credible next-step candidates → enrich contact details (candidate channel) → ready
for outreach. A pattern the agent composes from the capabilities below — not a hard-coded pipeline.

> **What's next + why:** this is the *source → shortlist* leg; the funnel continues to outreach → slate.
> See [`../recruiter-craft.md`](../recruiter-craft.md) §B for the recruiter decision at each stage.

> **Key rule:** the **competitor leg is an ADD-ON that *prioritizes*, never an exclusive filter.** You always run
> the general search; competitor-sourced candidates are *boosted to the top* because they carry the domain logic
> (they already sell/build for the same category). General profiles still fill the rest of the shortlist.

> **Promotion-ready is an ADD-ON too.** Search the same function one conventional level below the vacancy,
> then use dated work history to decide whether the person's experience has outgrown their current title. A
> lower title is a recall signal, not evidence of readiness or willingness to move. Keep every hard requirement,
> never infer that someone is actively looking, and do not reserve a final-shortlist quota for this lane.

## Capability chain
```
JD → PARSE (AI) → [DISCOVER COMPETITORS (exa)]
   → SEARCH (direct-fit + promotion lanes across general + competitor pools) → MERGE
   → ENRICH PROFILE (linkedin_profile — work history with dates) → QUALIFY + PROMOTION ASSESSMENT (AI) → RANK
   → ENRICH CONTACT (personal email) → (outreach)
```
> **Enrich the profile BEFORE you score.** Search output is a snapshot — current title, employer, location —
> and a title cannot tell a 20-year specialist from a 14-month career changer, nor find the relevant
> experience sitting behind an unrelated current title. Score on the dated work history (`linkedin_profile`,
> step 4) the way [`crm-matching.md`](crm-matching.md) scores on CRM history. Contact enrichment stays *after*
> qualification — you pay for emails only for survivors.

Docs this leans on: [`finding-people.md`](../finding-people.md) (search), [`enriching.md`](../enriching.md) (contact),
`prompts.json` (parse / qualify / competitors / outreach), [`references/provider-precedence.md`](../references/provider-precedence.md).

## Inputs
- **JD text** (any language). Optional: target count N (default 10), location override, "competitors only" off by default.

## Steps

**1 — PARSE the JD → canonical `PeopleQuery`** *(AI step — `hyreflow_agent.infer` with a schema)*
- Extract `{ titles[] (target-level role + EN/DE searchable variations), seniority, feeder_titles[],
  feeder_seniority, skills[] (must-haves only), certifications[], min_experience_years, locations[], keywords[] }`
  **plus** the **hiring company** `{name, domain, category}` **plus `reports_to`** (the manager role named in
  any reporting line / interview-panel title — used by the reporting-line-first hiring-manager rule in
  [`finding-people.md`](../finding-people.md)).
- **Build the promotion lane deliberately:** `feeder_titles[]` names the same function at one conventional
  level below the vacancy, and `feeder_seniority` carries that lower band. Examples: Senior Software Engineer
  → Software Engineer / Mid-level Software Engineer; Engineering Manager → Tech Lead / Engineering Lead;
  Sales Director → Sales Manager. A stale `Junior` title may be included when it is a plausible feeder in that
  market, but the later evidence gate must show target-level scope — the word "junior" alone proves nothing.
- Skip the lane when there is no defensible one-step progression, the user asks for exact incumbents only, or
  the role legally/operationally requires already-held accountability (for example a named licence, signatory
  authority, or executive ownership). Never bridge unrelated functions or multiple levels just to add volume.
- **Location rule:** if the role is remote with NO geographic/language requirement → `locations: []`; otherwise honor
  the stated region + any language requirement (e.g. "German C2" → DACH).
- → `POST /provider-playbooks/hyreflow_agent/infer` `{prompt(JD)+schema}`.

**2 — DISCOVER COMPETITORS** *(add-on; skip if the JD has no clear company/category)*
- `exa.answer("direct competitors of {company} ({domain}) in {category}")` → parse `Name (domain)` pairs.
  (Use the **"Find & verify competitors"** prompt for the agentic, domain-verified version. **Do NOT use
  `exa.find_similar` on the homepage — it returns directories, not competitors.**)
- → `POST /provider-playbooks/exa/answer` → competitor domains.

**3 — SEARCH (two source groups × two title paths → one deduped pool)**
- **Direct-fit path:** use `titles[]` + target `seniority` with the JD's must-have skills, certifications,
  experience floor and location. Run it across both source groups below.
- **Promotion path:** make a **separate** `people_search` call passing `feeder_titles[]` as its `titles` field and
  `feeder_seniority` as its `seniority` field, while
  keeping the **same must-have** skills, certifications, experience floor and location. Do not mix feeder titles
  with the target `seniority` in one query — that contradictory intersection can return zero. Do not relax a hard
  requirement to make a lower title fit. Tag `_candidate_path = promotion` (direct rows use `direct_fit`).
  Source roughly `0.5×N` promotion-path rows so the lane is material but cannot crowd out the target-level pool.
  Tenure coverage differs by source, so do not require a tenure filter here; step 4 supplies the dated evidence.
- **Source group A — competitor-priority** *(if step 2 ran):* for each competitor domain, run both applicable
  title paths **company-scoped** (`company_domains`/`company_names`). Tag `_source = competitor:<domain>`.
  → `POST /search/people_search` `{query:{...path filters, company_domains:[dom]}, coverage:"single"}` per competitor/path.
- **Source group B — general:** run both applicable title paths with **no company scope** (the broad market net).
  Tag `_source = general`.
  → direct: `POST /search/people_search` `{query:{...target filters}, coverage:"single", limit:~1.4×N}`
  → promotion: `POST /search/people_search` `{query:{...feeder filters}, coverage:"single", limit:~0.5×N}`.
- **Merge + dedup** by `linkedin_url`; union `_source` and `_candidate_path` when a person appears in several
  calls. Do not rank on title or promotion potential until dated work history arrives. Count-before-pay and put
  every added promotion-path call inside the same pilot/approval estimate as the direct path.

**4 — ENRICH PROFILE (work history) — the input QUALIFY scores on** *([`enriching.md`](../enriching.md))*
- `POST /enrich/linkedin_profile {"rows":[{"linkedin_url": …}, …]}` → each row gets a normalized
  `profile` = `{headline, current_title, current_company, experience[{company, title, start, end, is_current,
  duration_months?, description?}], about?, skills?, certifications?, education?}`, newest role first.
  First provider that carries employment history wins; a name-and-headline answer counts as a miss and costs
  nothing. **Field coverage varies by provider** — dated `experience[]` is the contract, while
  `about`/`skills`/`certifications` are filled only by providers that carry them (often empty), so treat their
  absence as unknown, never as "the candidate lacks it".
- Pass each row's `profile` straight through to step 5 — that's what carries the tenure the score needs.
- Rows already carrying history (a CRM/ATS record, `atlas.get_person`) don't need this step.

**5 — QUALIFY + ASSESS PROMOTION READINESS against the JD** *(AI step)*
- Score each candidate's profile vs the JD must-haves → `tier_1 | tier_2 | no_fit`; **drop `no_fit`**. This is the
  precision step (raw search is recall). Competitor-sourced candidates usually score higher but still get qualified.
  → `POST /provider-playbooks/hyreflow_agent/infer` per candidate (or batch).
  - **For a batch, use the `/qualify` endpoint** (the standard way to score all candidates in one call):
    `POST /qualify {"job_spec": <JD text>, "candidates": [Person, …], "min_score": <0-10 optional>}` →
    returns `{candidates:[{…, qualify:{score:0-10, basis, summary, strengths[], gaps[]}}], scored, count}`.
    It scores every candidate on the work history the row carries (`profile.experience[]` from step 4, or an
    `experience[]`/`work_experience[]` a CRM row already has) and reports `qualify.basis` per candidate:
    `work_history` or `title_only`. **A batch where NO row carries work history is refused (422
    `no_work_history`)** — enrich first, or pass `allow_thin_profiles: true` to accept a title-only ranking
    knowingly; mixed batches are scored and the thin rows are named in `_meta.thin_profiles`. **A `/qualify`
    call that errors, or a candidate whose `qualify.score` comes back null, gets surfaced to the user as-is
    — never subbed with your own guess.** Use this for *many candidates × one job*; use `infer` + the
    "Score job against CV" prompt for the *inverse* (one candidate × many jobs, e.g. `cv-to-jobs`).
    Interactive scoring stays free on the host agent (Model A).
- For every surviving `_candidate_path = promotion` profile, run `prompts.json` → **"Assess promotion readiness
  for target role"** on the full JD + dated history. It returns `promotion_ready | possible | not_supported`.
  `promotion_ready` requires all of the following evidence:
  - the current role is in the same function and one conventional level below (or a clearly stale lower label
    while the described scope is already at the intervening level);
  - the profile evidences the same must-have skills/certifications and meets the role's experience floor;
  - dates show sustained delivery at that level — default signal: at least 24 months in the current role, unless
    the profile contains stronger scope/progression evidence; a long-running `Junior Software Engineer` whose
    dated work already shows mid-level scope can therefore enter a Senior Software Engineer shortlist;
  - the target is a credible next step, not a multi-level leap or a move into a different function.
- Missing dates or scope are **unknown**, not positive evidence. A long tenure can mean either plateau or
  stickiness; it supports a promotion hypothesis but never proves willingness. Never infer that a candidate is
  actively looking without an explicit signal. Store `promotion_readiness`, `promotion_evidence[]`, and
  `promotion_gaps[]` so the recruiter can audit the call. Also store `promotion_mobility_signal = strong |
  moderate | weak | unknown`: `strong` needs evidence of target-level scope without matching title progression,
  not tenure alone; a recent move/promotion is `weak`, and missing dates are `unknown`.
- **Rank only after both passes:** JD fit/tier first; within the same tier, boost close competitor experience and
  `promotion_ready` candidates with a `strong`/`moderate` mobility signal. `possible` remains visible but gets no
  promotion boost; drop `not_supported` when the person entered only through the promotion path. A promotion-path
  candidate never outranks a stronger fit merely because their current title is lower.

**6 — ENRICH CONTACT (candidate channel)** *(`enriching.md`)*
- **Personal email + LinkedIn — NEVER work email** (candidates). `personal_email` waterfall (order in `reference/waterfalls.json`),
  first-hit; verify deliverability (`catch_all_safe` usable). → `POST /enrich/personal_email`.

**7 — OUTREACH** *(optional next stage)*
- Personalize (candidate first-line prompt) → enroll in a recruiting sequence. See `writing-outreach.md` (when built).

## Gates
- **Enrich the profile before you qualify** (a score on 3 sourcing fields is a guess), **and qualify before you
  enrich contact details** (don't pay for a `no_fit`'s email).
- **Credit & approval gate** — pilot one candidate end-to-end (steps 3→6 on one) → approval → full run. (SKILL.md)
- **Candidate channel** = personal email + LinkedIn (never work email). **EEO:** never filter on age/gender/etc.
- **Over-provision the direct path ~1.4×N plus a bounded ~0.5×N promotion pool**, count-before-pay,
  single-source-default. No fixed promotion quota in the final shortlist.

## Cost shape
| Step | Metered |
|---|---|
| 1 parse | AI tokens |
| 2 competitors | exa.answer (~) |
| 3 search (source groups + title paths) | per returned row/request; promotion-path calls are included in the approval estimate (current costs in cost-card.json) |
| 4 profile enrich | per-hit (`linkedin_profile` providers; a miss costs 0) |
| 5 qualify | AI tokens |
| 6 contact enrich | per-hit (personal-email providers) |
Free: dedup, ranking, the location/channel rules.

## Output
A **ranked, JD-qualified shortlist** containing direct-fit and credible promotion-ready candidates — with source
lineage, `_candidate_path`, promotion evidence/gaps, LinkedIn and personal email — ready for a candidate sequence.
Then render it with the **`hyreflow-artifact`** skill by default (candidates view, table first), unless the user asked for the CSV only.

## Notes from live runs
- exa.answer (not find_similar) for competitors; the answer text gives clean `Name (domain)`.
- Small/niche competitors may return 0 people (thin DB coverage) — the big ones carry the competitor leg; the general leg backstops.
- Raw search ≈ recall; **steps 4+5 (profile enrich → qualify) are what make the shortlist clean** — don't skip either.
- Scoring a pool on title + employer + location alone reorders it once the real history arrives: recent joiners at
  strong employers over-score, and specialists whose current title is generic under-score. Enrich, then rank.
- Treat "ready for a promotion" as an evidence-backed outreach angle, not a claim that the person is job-seeking.
