# Recipe — CRM Matching (match the client's OWN candidate base to a job)

**Use when:** the user's intent is "match candidates to *this* job" and a CRM/ATS is connected, or they
say they want to draw on their **existing candidate base** — whether the job lives in that connected
CRM/ATS or is external (pasted JD). This is a **recognized branch alongside pure net-new sourcing**
([`jd-to-shortlist.md`](jd-to-shortlist.md) / [`multi-strategy-sourcing.md`](multi-strategy-sourcing.md)),
not a replacement for it — **combine both** when the user wants coverage from their own base *and*
active net-new sourcing.

> **What's next + why:** this produces a ranked shortlist ready for the same next stage as any other
> sourcing leg — qualify/enrich survivors, then outreach or a CRM pipeline move. See
> [`../recruiter-craft.md`](../recruiter-craft.md) §B for the recruiter decision at each stage.

> **Key rule:** the differentiator is using the client's **own CRM taxonomy/custom fields** for
> prefiltering and their **historical candidate context** (notes/activities/interview history) for
> scoring — this is how CRM sourcing is actually done. A plain name/email search over the CRM candidate
> table (skipping taxonomy + history) is NOT this recipe — route that to the CRM's own
> `provider-playbooks/<tool>.md` instead.

## Capability chain
```
JOB (in CRM, or external JD) → PREFILTER (CRM-native taxonomy: skill tags / custom fields)
   → LONGLIST (broad: location, title variations) → ENRICH (CRM context: CV, notes, activities,
   past interviews/applications, past jobs shortlisted for) → SCORE (AI, job + profile + CRM history)
   → [optional] MERGE with net-new sourcing → ranked shortlist
```
Docs this leans on: the connected CRM's `provider-playbooks/<tool>.md` (auth + exact methods),
[`qualify-against-icp.md`](qualify-against-icp.md) (if a company-fit gate also applies),
[`references/provider-precedence.md`](../references/provider-precedence.md), `prompts.json`
("Score candidate against job using CRM history").

## Inputs
- **The job** — a CRM/ATS job id (recruit-crm/jobadder/vincere/loxo/bullhorn/recruiterflow/atlas), or
  external JD text if the role isn't tracked in the CRM.
- **The connected CRM/ATS** — exactly one; this recipe reads it, it doesn't merge multiple CRMs.
- Target N, and whether to **also** run net-new sourcing alongside (default: ask — combinable, not exclusive).

## Steps

**0 — Resolve the job**
- **In-CRM job:** read it with the tool's job-get method (e.g. `recruit-crm.get_job`, `jobadder.get_job`,
  `vincere.get_job`, `loxo.get_job`, `bullhorn.get_entity("JobOrder", id)`, `recruiterflow.get_job`,
  `atlas.get_project`) → title, must-haves, location.
- **External JD:** parse to a canonical query the same way as
  [`jd-to-shortlist.md`](jd-to-shortlist.md) step 1 — `hyreflow_agent.infer` with a schema
  (`{titles[], skills[], locations[], seniority, keywords[]}`).

**1 — PREFILTER on the CRM's OWN taxonomy** *(the differentiator — never skip straight to name/email)*
Filter the candidate base on fields that only exist **inside this client's CRM** — skill tags, custom
fields, their own taxonomy — before touching generic attributes. Support varies by CRM:

| CRM | Native custom-field / tag filter | Method |
|---|---|---|
| **recruit-crm** | Yes — `custom_fields` is a first-class search param | `search_candidates(*, custom_fields=[...], **filters)`; discover field IDs with `list_custom_fields("candidate")` |
| **jobadder** | Yes — richest surface | `get_candidate_custom_fields()` for field IDs, `get_candidate_skills(id)` for tags, then filter client-side or via `find_candidates(**params)` |
| **recruiterflow** | Filter-body supports `custom_field.N` keys (confirmed on `search_jobs`, mirrors onto candidates) | `search_candidates({"conjunction":..., "filters":[{"key":"custom_field.<N>", ...}]})` |
| **bullhorn** | Indirect — custom fields are plain entity fields, no dedicated tag param | `search("Candidate", "<lucene w/ custom field>", fields="*")` or `query("Candidate", "<where>", fields="*")` |
| **vincere** | Indirect — Lucene `q` string only, no dedicated custom-field param | `search_candidates(q="<lucene>", fl="<fields>")` |
| **loxo** | Not exposed — `query` is free-text only | `list_people(query="...")` — fall back to Step 1b |
| **atlas** | Not exposed — search is identity-only (email/phone/LinkedIn) | none — fall back to Step 1b |

**1b — Fallback when the CRM has no native custom-field filter (loxo, atlas, and thin bullhorn/vincere
setups):** pull the broader candidate set from Step 2's location/title filters first, then apply the
taxonomy filter as an AI step over each candidate's tags/notes text (`hyreflow_agent.infer`) instead of
a server-side query. Slower and token-metered, but still honors the "CRM taxonomy first" principle —
never silently drop straight to generic-only matching.

**2 — LONGLIST broad on core matchable attributes**
On the Step-1 survivors (or the whole base, if Step 1b applies after this step), longlist by location and
job-title variations — **always broad first**, the same over-provision discipline as any sourcing leg
(~1.4×N; see SKILL.md "Over-provision, then filter"). Don't narrow the location/title net here — Step 4's
AI score is the precision step, not this one.

**3 — ENRICH the longlist with rich CRM context**
For each longlisted candidate, pull the CRM's own historical context — this is what a generic people-DB
can never give you:

| CRM | CV / attachments | Notes / conversations | Interviews / applications | Past jobs shortlisted for |
|---|---|---|---|---|
| **recruit-crm** | `get_candidate(slug)` (resume field) | — (see field-notes if not itemized) | `get_candidate_hiring_stages(slug)` — every job + stage the candidate has been in | same as prior column |
| **jobadder** | `find_candidate_attachments(candidate_id)` | `find_notes(CandidateId=...)` | `get_candidate(id, embed="skills,notes,applications,placements")`, `find_applications(CandidateId=...)` | `find_placements(CandidateId=...)` |
| **loxo** | `get_person(person_id)` (resume field) | — | `list_job_candidates` per job (pipeline stage) | cross-reference via `list_jobs` + `list_job_candidates` |
| **vincere** | `get_candidate(id, fields=...)` | — | — (no dedicated method documented; check `reference/docs` before assuming absent) | — |
| **bullhorn** | `get_entity("Candidate", id, fields="*")` (resume/file fields) | same call, wider `fields` | `get_entity("JobSubmission", id, fields="*")` per submission | `search("JobSubmission", "candidate.id:<id>")` |
| **recruiterflow** | `list_candidates(include_files=1)` | `list_candidates(include_notes=1)` | `get_job_pipeline(job_id)` cross-referenced by candidate | same |
| **atlas** | — (no attachment method documented) | — (`add_person_note` is write-only; no GET-notes method) | `list_project_candidates(project_id)` per project | `list_candidates(personId=...)` agency-wide |

Where a CRM doesn't expose a method (`—` above), don't fabricate one — note the gap to the user and score
on what's available rather than stalling the whole run.

**4 — SCORE by feeding the CRM context into an AI scoring prompt**
Score each enriched candidate against the job using **prompts.json → "Score candidate against job using
CRM history"** (not the plain "Score candidate against job (0-10)" — that one deliberately ignores
anything beyond the profile). This is the step that makes CRM matching different from a cold search:
prior interview outcomes and past-job history move the score, not just the resume.
- → `hyreflow_agent.infer(prompt, schema=SCORE_SCHEMA)` per candidate — interactive scoring stays free
  on the customer's Claude (Model A); use the metered batch path only at scale.

**5 — Optional: MERGE with net-new sourcing**
If the user also wants active net-new sourcing (the default combinable case), run
[`jd-to-shortlist.md`](jd-to-shortlist.md) or [`multi-strategy-sourcing.md`](multi-strategy-sourcing.md)
in parallel, tag `_source = crm:<tool>` vs `_source = net-new`, dedupe by email/LinkedIn, and present one
ranked shortlist — CRM-matched candidates surfaced with their score **and** the CRM signals that drove it,
net-new candidates alongside.

## Gates
- **CRM reads are the client's own BYOK data** — Steps 0–3 are exempt from the credit/approval gate
  (see SKILL.md "When NOT to gate"). If Step 1b's AI-tag-filter or Step 4's scoring runs at scale via the
  metered batch path, that's token spend — gate it like any other AI-at-scale call.
- **Qualify before you spend anything paid** — if net-new sourcing (Step 5) is combined in, that leg still
  runs [`qualify-against-icp.md`](qualify-against-icp.md) before its own enrichment.
- **EEO / compliance:** never filter or score on protected attributes (age/gender/marital/etc.) even if a
  CRM custom field happens to expose them — taxonomy filtering means skills/role/location tags, not that.

## Cost shape
| Step | Metered |
|---|---|
| 0 resolve job | free (CRM read) or AI tokens (JD parse) |
| 1 prefilter | free (CRM read) — or AI tokens if using the 1b fallback |
| 2 longlist | free (CRM read) |
| 3 enrich CRM context | free (CRM read) |
| 4 score | AI tokens (interactive, free) or metered at scale |
| 5 optional net-new merge | per the merged recipe's own cost shape |

## Output
A ranked shortlist of the client's **own** candidates against the job, each carrying its AI score, the
specific CRM signals (notes/interview/past-job facts) that drove it, and — when combined — net-new
candidates merged in and clearly tagged by source. Ready for outreach or a CRM pipeline move
(`update_candidate_hiring_stage` / `move_candidate_to_stage` / equivalent).

## Notes
- Custom-field/tag filtering support varies widely across CRMs (see Step 1's table) — recruit-crm and
  jobadder expose it cleanly; loxo, vincere, and atlas don't document a native filter, so Step 1b's
  AI-tag-filter fallback is not an edge case, it's the common path for those three.
- Don't treat this as "search the CRM by keyword" — the whole point is prefiltering on the client's own
  taxonomy (Step 1) and scoring on their own history (Step 4), not generic fields any people-DB has.
