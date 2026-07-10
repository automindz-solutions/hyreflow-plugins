# Recipe: IT / developer sourcing (GitHub + people-DBs → shortlist)

Source engineers for an IT role using **two parallel legs** — **GitHub** (free, ground-truth skill proof) and the
**people-DBs** (breadth: devs not on GitHub + employer context) — merge, qualify against the JD, and deliver a
candidate shortlist with a rich dossier. A pattern the agent composes; not a hard-coded pipeline.

> **Engine-routed (SKILL.md → Execution model):** every method below runs as
> `hyreflow tools execute <provider>_<method>` — e.g. GitHub `search_users` → `hyreflow tools execute
> github_search_users`. The engine holds the keys server-side. **Do not** check your local env for keys,
> call GitHub/Apollo directly, or write a local ingestion script.

> **Why GitHub leads for IT:** the API is **free** (token; ~5k REST + 5k GraphQL/hr, 30 searches/min) and gives
> *evidence* a people-DB can't — real languages/repos/stars, a **personal email** (commit harvest), and
> website/LinkedIn/socials. But it only covers **OSS-active** devs → the people-DB leg backstops everyone else.
>
> **⚠️ Dev vs. infra — pick the primary by role type (don't reach for GitHub reflexively):**
> - **Code-writing roles** (SWE, data/ML, backend/frontend, devs-who-code) → **GitHub leg is primary** (ground-truth skill).
> - **Infrastructure / sysadmin / network / IT-support / ops / Windows-AD-M365 admin** → these people **don't write public
>   code** → **GitHub is ~N/A; SKIP it and make the people-DBs primary** (search by title + skills + location). A
>   "Systemadministrator (Windows Server/AD/Azure)" has no representative GitHub. Skill keywords go in `skills` (people_search), not languages.

## Capability chain
```
IT JD/role → PARSE (AI) →  ┌─ GitHub leg:    search_users → candidate_dossier/user_dossier (or GraphQL dossier) → [Firecrawl+AI deep context]
                           └─ people-DB leg: people_search (aiark → … )
           → MERGE + dedup (prioritise GitHub-sourced) → QUALIFY 0-10 → shortlist (LinkedIn-first + personal email)
```
Docs: [`provider-playbooks/github.md`](../provider-playbooks/github.md) (the dossier + email rules), [`finding-people.md`](../finding-people.md),
[`enriching.md`](../enriching.md), [`references/provider-precedence.md`](../references/provider-precedence.md).

## Steps

**1 — PARSE (if from a JD)** *(AI step)* — extract the IT `PeopleQuery`: `titles`, **`skills`/languages** (e.g. Java, Python),
`certifications`, `min_experience_years`, `locations`, `seniority`, + `reports_to` if a manager is named. (See `jd-to-shortlist`.)

**2 — GitHub leg** *(free, ground-truth; the prioritised source)*
- **Fast batch path — first-class helpers** (prefer these over agent-authored local scripts for candidate rows
  coming out of people-DB/JD sourcing):
  - `search_profile_match` — `full_name + company/location/linkedin_url → ranked GitHub matches`.
  - `candidate_dossier` — end-to-end `identity match → repo/social/email dossier → JD keyword scoring`.
  - `user_dossier` — when you already have a GitHub login/URL.
  - ⚠️ **Impact is owned-repo-only.** These helpers read `list_user_repos` (REST), so their `impact_tier`/
    `flagship_repo` see a user's **own** repos only — they **undercount org-owned flagships** (a maintainer of
    FastAPI under `fastapi/` reads as ~3k, not 99k). Fine for ranking the pool; for an accurate impact read on a
    finalist, use the GraphQL dossier below.
- `search_users` `q="location:<geo> language:<L1> language:<L2> followers:>N"` — multi-`language:` **ANDs** (devs with both).
  Search a few **city variants** (location is free-text → `Germany`/`Berlin`/`Munich`) for coverage; sort by followers.
- **High-accuracy impact — one GraphQL dossier per candidate** (see `provider-playbooks/github.md`): `websiteUrl`,
  **all** `socialAccounts` (LinkedIn first), `followers`, and
  `repositories(ownerAffiliations:[OWNER,ORGANIZATION_MEMBER,COLLABORATOR], orderBy:STARGAZERS)` →
  **impact tier** from top-repo stars (**≥5k viral · ≥1k strong · ≥100 notable**). `ownerAffiliations` MUST include
  ORG/COLLABORATOR or you undercount org-owned flagships (FastAPI/Netty) — the gap the helpers above can't close.
- **Email:** `find_user_emails` (harvests commit emails) → **personal only** (discard employer-domain + `*noreply*`).
- **Drop bots** — exclude `*[bot]` logins (e.g. `dependabot[bot]`, `github-actions[bot]`) from any
  `search_users` / `get_repo_contributors` list before dossiering; they're not candidates.
- **Always include the GitHub profile URL.**
- **`jd_score` = JD-keyword COVERAGE on a 0-10 scale** (fraction of your `jd_keywords` the candidate
  demonstrates across their repos × 10). It is comparable across candidates and stable as the JD grows.
  `impact_tier` is a *separate* fame signal — rank on **both** (relevance × reach), not `jd_score` alone.

**Size to the ask.** The deliverable is **exactly N** — the count the user requested (e.g. "10 engineers" → N=10).
Pull the GitHub pool at **~3×N** (cap ~50): enough headroom to absorb non-ICP noise and the qualify drop, without
dossiering hundreds. Set `per_page ≈ 3×N`, **not a flat 60**. Then QUALIFY down to the top N (step 6). Pulling 80 for
N=10 wastes time + API budget — the pool is a means to N, not the output.

**No-script batch flow (canonical — do NOT hand-write Python loops).** Pool → dossiers → CSV entirely via the CLI
(example: target N=10 → `per_page` 30):
```bash
# 1. pool to CSV (the {items:[...]} envelope writes directly) — per_page ≈ 3×N
hyreflow tools execute github_search_users --payload '{"q":"location:London language:Python followers:>30","per_page":30,"sort":"followers"}' --output pool.csv
# 2. dossier every row through the enrich engine (one column out), JD-scored, to CSV — no subprocess/JSON parsing
hyreflow enrich --input pool.csv \
  --with '{"alias":"gh","tool":"github_user_dossier","payload":{"username":"{{login}}","jd_keywords":["java","payments","spring","kafka"]},"extract_js":"return {jd_score:result.jd_score, impact:result.impact_tier, email:(result.commit_emails||[]).find(e=>!/noreply/.test(e)), linkedin:result.linkedin_url, langs:(result.languages||[]).join(\"|\")}"}' \
  --output dossiers.csv
```
For people-DB rows that have a name + company but no handle, swap the step to `github_candidate_dossier`
with `{"full_name":"{{first_name}} {{last_name}}","company_name":"{{company}}",...}`. `--with`'s `tool` is
**always the flat `<tool>_<method>` name** (e.g. `github_user_dossier`, `github_candidate_dossier`) — never
dotted. Placeholders `{{col}}` pull from the input row; `extract_js` flattens the dossier to columns.

**2b — Verify JD tool/framework requirements via `search_code`** *(per-candidate ground truth; after geo sourcing)*
- Parse the JD's **specific tooling/framework requirements** into code fingerprints, then run `search_code` on each
  sourced GitHub login to tag the dossier with evidence. Examples:
  - Quality tooling: `"[tool.ruff]" user:<login>`, `"[tool.mypy]" user:<login>`
  - Testing: `pytest user:<login>`, `filename:conftest.py user:<login>`, `filename:pytest.ini user:<login>`
  - Framework imports: `"from fastapi" user:<login>`, `"from django" user:<login>`, `"from flask" user:<login>`
  - CI gates: `filename:*.yml "ruff check" user:<login>`
- Run via the flat tool name (same convention as dossiers):
  ```bash
  hyreflow tools execute github_search_code --payload '{"q":"\"[tool.ruff]\" user:<login>","per_page":1}'
  ```
  Read `result.total_count`; you usually only need counts, not file contents.
- **Batch rate-windowed passes:** GitHub code search has a stricter **10 queries/min** bucket. Check
  `github_get_rate_limit` / `get_rate_limit().resources.code_search`, batch candidates by fingerprint, and pause
  between windows.
- **No `location:` qualifier exists for code search.** Pipeline = `search_users` / people-DB geo sourcing → dossier
  known candidates → `search_code user:<login>` verification → tag/rank. Do **not** use code search as a standalone
  geo+tool sourcing filter.
- **Interpretation rule: Presence = strong evidence; absence = weak evidence.** Code search indexes public,
  default-branch files only, so private/company repos and non-default branches under-show. Never hard-reject a good
  candidate on a zero; read zeros in context (e.g. someone may author Litestar and therefore score low on
  FastAPI/Django/Flask import fingerprints while still being a strong ASGI/backend candidate).
- Add verified-tooling columns to the shortlist when relevant, e.g. `verified_ruff`, `verified_mypy`,
  `verified_pytest`, `verified_frameworks`, `verified_ci_quality_gates`, plus short evidence notes/counts.

**3 — People-DB leg** *(breadth — the devs not on GitHub)*
- `people_search` waterfall (aiark → …) with the JD's **canonical** query keys: `titles`, `skills`,
  `locations`, `seniority`, `min_experience_years`, `company_domains`, `limit`. ⚠️ Use these exact names —
  provider-native keys like `person_locations`/`person_titles` are auto-aliased but anything unrecognized is
  **dropped and reported in `_meta.ignored_query_keys`** (a mistyped filter silently widens the search).
  Tag `_source=people_db`.
- ⚠️ **`skills` ≫ `title` as the precision lever for IT roles.** `skills` pushes down to aiark
  `contact.skill` and prefilters at the source — a title-only pull (e.g. "Backend Engineer") drags in
  off-stack rows you then pay to filter client-side. Lead with the JD's stack (e.g.
  `"skills":["Python","FastAPI"]`); titles widen, skills narrow.
- **Geo precision:** the managed aiark source is loose on free-text locations; if you need a hard
  geo+title constraint (e.g. "London, payments"), Apollo's flat `apollo_search_people` honors
  `person_locations` precisely — but Apollo is **BYOK-only**. Without a workspace Apollo key it is
  unavailable/skipped with `no_key`. Treat Apollo as an optional override, not the default leg.

**4 — MERGE + dedup** — by `linkedin_url` (fallback GitHub login / name+company). **Prioritise GitHub-sourced** candidates
(real skill proof beats self-reported); people-DB rows fill the rest. Over-provision ~1.4×N.

**5 — DEEP CONTEXT (optional; gate to the SHORTLIST only — it's per-candidate cost)**
- `firecrawl.scrape(personal_website)` → `hyreflow_agent.infer` → `{summary, notable_projects[], tech[], talks_or_content[]}`
  (grounded in the scraped text). Enriches both qualify and personalization. Don't run it on the raw pool — only the finalists.

**6 — QUALIFY 0-10 vs the JD** *(`/qualify`)* — score each candidate's dossier (skills + impact tier + deep context),
then **deliver exactly the top N** the user asked for (rank by score, cut the rest). The precision step (search =
recall). GitHub-sourced usually score high (evidence-backed). Don't hand back the whole pool — N is the deliverable.

**7 — OUTREACH handoff** — candidate channel = **LinkedIn-first → personal email** (GDPR-aware; harvested emails are
unconsented). See `writing-outreach.md`.

## Gates
- **Candidate channel:** personal email + LinkedIn, **never work email** — and from the GitHub harvest, **discard employer-domain** addresses.
- **GDPR / LinkedIn-first** for commit-harvested personal emails (mostly EU devs).
- **EEO:** never filter on age/gender/etc.
- **Qualify before spend**; **gate deep-context to the shortlist**; over-provision then filter; count-before-pay on the people-DB leg.

## Cost shape
| Step | Metered? |
|---|---|
| GitHub leg (search, dossier, email) | **free** (token; ~$0) |
| people-DB leg | metered (aiark ~0.07, etc.) |
| deep context (Firecrawl + AI) | metered — **gate to finalists** |
| qualify (AI) | metered (tokens) |
So GitHub sourcing + emails are free margin; you meter the people-DB breadth + the Firecrawl/AI enrichment.

## Output
A ranked IT shortlist, GitHub-sourced first, each with: **GitHub URL · website · LinkedIn (+ socials) · impact tier
(flagship repo) · personal email · deep-context (projects/tech/talks) · 0-10 JD score.**

## Notes from live runs
- Multi-`language:` ANDs in GitHub user search (verified: `location:Germany language:Java language:Python` → 5.7k).
- **Org-inclusive stars are essential** — without `ORGANIZATION_MEMBER` you saw tiangolo as 3k vs the real FastAPI 99k.
  The `candidate_dossier`/`user_dossier` helpers use REST `list_user_repos` (owned only) → same undercount; switch to
  the GraphQL dossier when a finalist's impact tier hinges on an org-owned flagship.
- `find_user_emails` returns **work + personal** → keep personal (gmail/personal-domain), drop employer (`@google.com`…).
- `lib/github.py` `graphql()` returns the **unwrapped** data (top-level `user`).
- GitHub coverage skews **OSS-active** → always run the people-DB leg too for breadth.
