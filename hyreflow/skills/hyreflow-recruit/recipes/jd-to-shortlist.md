# Recipe: JD → Shortlist (with competitor-poach priority)

**The most-requested recruiter play.** Paste a job description → extract searchable filters → source candidates
(**general search + prioritized competitor profiles**) → enrich the profiles (work history) → qualify against the
JD → enrich contact details (candidate channel) → ready for outreach. A pattern the agent composes from the capabilities below — not a hard-coded pipeline.

> **What's next + why:** this is the *source → shortlist* leg; the funnel continues to outreach → slate.
> See [`../recruiter-craft.md`](../recruiter-craft.md) §B for the recruiter decision at each stage.

> **Key rule:** the **competitor leg is an ADD-ON that *prioritizes*, never an exclusive filter.** You always run
> the general search; competitor-sourced candidates are *boosted to the top* because they carry the domain logic
> (they already sell/build for the same category). General profiles still fill the rest of the shortlist.

## Capability chain
```
JD → PARSE (AI) → [DISCOVER COMPETITORS (exa)] → SEARCH (general + competitor-priority, merged & ranked)
   → ENRICH PROFILE (linkedin_profile — work history with dates) → QUALIFY (AI)
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

**5 — QUALIFY against the JD** *(AI step — `prompts.json` → "Qualify candidate against role")*
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
- **Over-provision ~1.4×N**, count-before-pay, single-source-default.

## Cost shape
| Step | Metered |
|---|---|
| 1 parse | AI tokens |
| 2 competitors | exa.answer (~) |
| 3 search (both legs) | aiark ~3.0 per leg/competitor (first source that hits; current costs in cost-card.json) |
| 4 profile enrich | per-hit (`linkedin_profile` providers; a miss costs 0) |
| 5 qualify | AI tokens |
| 6 contact enrich | per-hit (personal-email providers) |
Free: dedup, ranking, the location/channel rules.

## Output
A **ranked, JD-qualified shortlist** — competitor-sourced candidates first, general profiles filling the rest — each
with LinkedIn + personal email, ready for a candidate sequence.

## Notes from live runs
- exa.answer (not find_similar) for competitors; the answer text gives clean `Name (domain)`.
- Small/niche competitors may return 0 people (thin DB coverage) — the big ones carry the competitor leg; the general leg backstops.
- Raw search ≈ recall; **steps 4+5 (profile enrich → qualify) are what make the shortlist clean** — don't skip either.
- Scoring a pool on title + employer + location alone reorders it once the real history arrives: recent joiners at
  strong employers over-score, and specialists whose current title is generic under-score. Enrich, then rank.
