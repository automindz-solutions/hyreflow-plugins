# Recipe: JD → Shortlist (with competitor-poach priority)

**The most-requested recruiter play.** Paste a job description → extract searchable filters → source candidates
(**general search + prioritized competitor profiles**) → qualify against the JD → enrich (candidate channel) →
ready for outreach. A pattern the agent composes from the capabilities below — not a hard-coded pipeline.

> **What's next + why:** this is the *source → shortlist* leg; the funnel continues to outreach → slate.
> See [`../recruiter-craft.md`](../recruiter-craft.md) §B for the recruiter decision at each stage.

> **Key rule:** the **competitor leg is an ADD-ON that *prioritizes*, never an exclusive filter.** You always run
> the general search; competitor-sourced candidates are *boosted to the top* because they carry the domain logic
> (they already sell/build for the same category). General profiles still fill the rest of the shortlist.

## Capability chain
```
JD → PARSE (AI) → [DISCOVER COMPETITORS (exa)] → SEARCH (general + competitor-priority, merged & ranked)
   → QUALIFY (AI) → ENRICH (personal email + LinkedIn) → (outreach)
```
Docs this leans on: [`finding-people.md`](../finding-people.md) (search), [`enriching.md`](../enriching.md) (contact),
`prompts.json` (parse / qualify / competitors / outreach), [`references/provider-precedence.md`](../references/provider-precedence.md).

## Inputs
- **JD text** (any language). Optional: target count N (default 10), location override, "competitors only" off by default.

## Steps

**1 — PARSE the JD → canonical `PeopleQuery`** *(AI step — `hyreflow_agent.infer` with a schema)*
- Extract `{ titles[] (role + EN/DE searchable variations), skills[] (must-haves only), certifications[],
  min_experience_years, locations[], seniority, keywords[] }` **plus** the **hiring company** `{name, domain, category}`
  **plus `reports_to`** (the manager role named in any reporting line / interview-panel title — used by the
  reporting-line-first hiring-manager rule in [`finding-people.md`](../finding-people.md)).
- **Location rule:** if the role is remote with NO geographic/language requirement → `locations: []`; otherwise honor
  the stated region + any language requirement (e.g. "German C2" → DACH).
- → `POST /provider-playbooks/hyreflow_agent/infer` `{prompt(JD)+schema}`.

**2 — DISCOVER COMPETITORS** *(add-on; skip if the JD has no clear company/category)*
- `exa.answer("direct competitors of {company} ({domain}) in {category}")` → parse `Name (domain)` pairs.
  (Use the **"Find & verify competitors"** prompt for the agentic, domain-verified version. **Do NOT use
  `exa.find_similar` on the homepage — it returns directories, not competitors.**)
- → `POST /provider-playbooks/exa/answer` → competitor domains.

**3 — SEARCH (two legs → one deduped, ranked pool)**
- **Leg A — competitor-priority** *(if step 2 ran):* for each competitor domain, run the people-search waterfall
  **company-scoped** (pass `company_domains`/`company_names`) with the JD filters (titles/skills/exp/location). Tag
  `_source = competitor:<domain>`.
  → `POST /search/people_search` `{query:{...JD filters, company_domains:[dom]}, coverage:"single"}` per competitor.
- **Leg B — general:** run the waterfall with the JD filters and **no company scope** (the broad market net). Tag `_source = general`.
  → `POST /search/people_search` `{query:{...JD filters}, coverage:"single", limit:~1.4×N}`.
- **Merge + dedup** (by `linkedin_url`), then **rank competitor-sourced first**, general fills the rest. Over-provision ~1.4×N.

**4 — QUALIFY against the JD** *(AI step — `prompts.json` → "Qualify candidate against role")*
- Score each candidate's profile vs the JD must-haves → `tier_1 | tier_2 | no_fit`; **drop `no_fit`**. This is the
  precision step (raw search is recall). Competitor-sourced candidates usually score higher but still get qualified.
  → `POST /provider-playbooks/hyreflow_agent/infer` per candidate (or batch).
  - **Batch alternative — the `/qualify` endpoint** (scores all candidates in one call):
    `POST /qualify {"job_spec": <JD text>, "candidates": [Person, …], "min_score": <0-10 optional>}` →
    returns `{candidates:[{…, qualify:{score:0-10, summary, strengths[], gaps[]}}], scored, count}`. Use this
    for *many candidates × one job*; use `infer` + the "Score job against CV" prompt for the *inverse*
    (one candidate × many jobs, e.g. `cv-to-jobs`). Interactive scoring stays free on the customer's Claude (Model A).

**5 — ENRICH (candidate channel)** *(`enriching.md`)*
- **Personal email + LinkedIn — NEVER work email** (candidates). `personal_email` waterfall (`fullenrich → leadmagic → wiza`),
  first-hit; verify deliverability (`catch_all_safe` usable). → `POST /enrich/personal_email`.

**6 — OUTREACH** *(optional next stage)*
- Personalize (candidate first-line prompt) → enroll in a recruiting sequence. See `writing-outreach.md` (when built).

## Gates
- **Qualify before enrich** (don't pay to enrich `no_fit`).
- **Credit & approval gate** — pilot one candidate end-to-end (steps 3→5 on one) → approval → full run. (SKILL.md)
- **Candidate channel** = personal email + LinkedIn (never work email). **EEO:** never filter on age/gender/etc.
- **Over-provision ~1.4×N**, count-before-pay, single-source-default.

## Cost shape
| Step | Metered |
|---|---|
| 1 parse | AI tokens |
| 2 competitors | exa.answer (~) |
| 3 search (both legs) | aiark ~3.0 per leg/competitor (first source that hits; current costs in cost-card.json) |
| 4 qualify | AI tokens |
| 5 enrich | per-hit (personal-email providers) |
Free: dedup, ranking, the location/channel rules.

## Output
A **ranked, JD-qualified shortlist** — competitor-sourced candidates first, general profiles filling the rest — each
with LinkedIn + personal email, ready for a candidate sequence.

## Notes from live runs
- exa.answer (not find_similar) for competitors; the answer text gives clean `Name (domain)`.
- Small/niche competitors may return 0 people (thin DB coverage) — the big ones carry the competitor leg; the general leg backstops.
- Raw search ≈ recall; **step 4 qualify is what makes the shortlist clean** — don't skip it.
