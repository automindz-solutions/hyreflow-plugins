# Recipe: Build TAM — ICP → addressable company list (+ optional people)

**The "which companies should I even be targeting?" play.** Turn a recruiter's ICP into a list of **real
ICP-fit companies** (their addressable market / target accounts), then — only if they want — the **relevant
people** in those companies (hiring managers and/or candidates), enriched and pushed to outreach / the ATS.

> **TAM membership = firmographic / ICP fit. Hiring is NEVER a TAM signal.** A company is in the TAM even if
> it has no open req right now. Active job postings (theirstack, predictleads) are **timing triggers** for the
> *outreach* stage, **never** a membership filter.
> **Geo-presence (when the ICP needs it):** for a "HQ can be anywhere, must be relevant in market X" rule
> (e.g. Nobel: Benelux/Nordics), the correct signal is **present employment — does the company already employ
> target job titles *located in* market X** (e.g. AEs/SDRs sitting in NL/BE/Nordics)? That proves a real local
> team (they hired there at some point), and you check it via **Path B (people-first reverse)** — NOT by
> looking at open postings.

## Core deliverable & channel
- **Deliverable = the qualified ICP-fit company list.** People → enrich → outreach → ATS are **opt-in
  follow-on stages** (Step 5), not run by default.
- Channel only matters in Step 5: hiring managers → **work email**; candidates → **personal email + LinkedIn**.

## Output dir
`clients/<client-slug>/runs/tam-<icp-slug>/` (or `<cwd>/hyreflow-runs/tam-<icp-slug>/`). UTF-8 (BOM for Excel).

## Capability chain
```
RESOLVE ICP (cascade) → SOURCE companies  [A firmographic-filter ‖ B people-first-reverse ‖ C lookalike-from-seeds]
  → merge+dedup → COUNT-FIRST (TAM size) → QUALIFY (hard filters → Model-A fuzzy-fit → ICP-driven web verification)
  → ICP-FIT company list (tiered + evidence)  → [OPTIONAL] people (HMs &/or candidates) → enrich → outreach / ATS
```

---

## STEP 0 — Resolve the ICP (cascade, best → worst)
1. **`ICP.md` exists** (built by `/icp` at onboarding, in the client dir) → use it. Best.
2. **Else: derive from seeds.** Ask for an **active-client list / Dream-100 / CSV**, or pull the client's
   existing accounts from their ATS (`recruit_crm.list_companies` · `recruiterflow.list_clients` ·
   `vincere.search_companies` · `jobadder.find_companies` · bullhorn `query("ClientCorporation")`). Then
   `prompts.json → "Derive ICP from seed accounts"` clusters the common **industry / size / geo / tech /
   keywords / funding** + the **proof signals** that define fit. More accurate than (3).
3. **Else: natural-language ICP** from the user → structure into filters. Flag as **least accurate**.

→ A **working ICP** = hard firmographic filters + a qualitative fit definition + the **proof-signals to verify**
(Step 3). Write it to the run dir so the whole run qualifies against one source of truth.

## STEP 1 — Source candidate companies (run one path, or combine for a "cumulative" TAM)
Default to a single primary source (count-first), fan out only for more coverage (`provider-precedence` —
single-source-default).

- **A — Firmographic filter (default).** ICP → company-search filters on a primary firmographic DB —
  **AI Ark `company_search`** (rich `AccountFilter` + already keyed; a strong default), Apollo, Prospeo, or
  Lusha. Use **industry + keywords + tech (inline) + employee size + geo + revenue + NAICS/SIC + type**
  (+ AI Ark `retailSize` for # locations, `metric` for headcount growth, `funding`). **Keywords + tech +
  lookalikes are what catch the mislabeled-industry problem** — e.g. SaaS firms tagged by their *vertical*
  (fintech, healthtech…) rather than "Software Development"; AI Ark's `keyword` with DESCRIPTION/SEO sources
  is especially good here. **No hiring-signal filters.**
- **B — People-first reverse (niche roles AND geo-presence).** `people_search` (**AI Ark default** — richest
  profiles) by the **target job titles**, optionally **scoped to the target locations** → roll up unique
  `company_name`/`company_domain` → those companies *demonstrably employ the target talent there*. Two uses:
  (1) niche roles a firmographic filter misses; (2) **the geo-presence test** — to satisfy a "HQ-anywhere,
  relevant in market X" ICP rule, search the ICP's titles + market-X locations → any company that turns up
  **already employs that talent in X** (real local team — the correct signal, **not** open postings).
  (Per-person company fields come back on `/search`; dedup to companies.)
- **C — Lookalike from seeds.** Seeds = ATS clients / Dream-100 / CSV → expand via **prospeo**
  (`enrich_company`→`company_id`→`search_company company_lookalike` T1/T2/T3), **lusha** `company_lookalikes`,
  **zoominfo** `company_lookalikes`, **predictleads** `similar_companies`, **exa** `find_similar`.
  ⚠️ **Verify each seed resolves to the right company** before lookalike-ing (the `provider-playbooks/prospeo.md` seed-verify
  rule — a bare shared-SaaS domain mis-resolves).

→ **Merge + dedup by domain**; tag `_source` (which path/DB) for lineage.

## STEP 2 — Count-first (the TAM-size headline) → cost projection
Before pulling depth, **peek the total match count** (count-before-pay, ~free): AI Ark `result.totalElements`,
Prospeo `result.pagination.total_count`, Apollo `result.total_entries`, Lusha `result.total`, theirstack count.
The count lives under the `result` envelope every `tools execute` returns (`{ _meta, result }`) — a top-level
read returns `None`. That number **is the TAM size estimate** — report it up front.

**Then project the full-run cost from it** (the free count is the top of the funnel; cost is driven by how
many survive to the *paid* steps). Walk the funnel with the current per-op credit costs from the registry
(`reference/tool-registry.json`; firms up with the price card):
```
TAM_total (free count)
  → sourcing pulls           : cheap (a few calls × ~3.0; lookalikes extra)
  → hard + Model-A qualify    : FREE (Step 3 T1/T2)
  → web verification (T3)     : verify_N × (serper free + firecrawl ~0.5 + agent)  ≈ ~0.5/company
  → [opt] people per company  : people_search ~3.0/company
  → [opt] enrich per person   : work email ~0.5–3.0/hit · personal-email waterfall varies
```
So **est. credits ≈ web-verify(verify_N) + [people_search × companies] + [enrich × people]**, where
`verify_N` = the count that passes the free hard+LLM filters (assume a pass-rate band, e.g. 30–60% of the
pulled set, and say so). Present this as a **range tied to depth** (e.g. "top 200 of 3,180 → ~Xcr to a
verified shortlist; full 3,180 → ~Ycr") in the **approval message** so the recruiter picks depth/budget
*before* any spend. Never blind-paginate a paid source.

## STEP 3 — QUALIFY (the heart — industry-agnostic, accuracy-first; 3 tiers)
Follow [`recipes/qualify-against-icp.md`](qualify-against-icp.md), extended with a verification tier. Gate
**before** any enrichment (never pay to process non-fit companies).

1. **T1 — Hard filters (free).** Apply the ICP's must-haves (industry / size / geo / type / exclusions) to the
   data the search already returned. Drop clear misses.
2. **T2 — Model-A fuzzy-fit (free, the host agent).** Read each survivor + the ICP → tier/score. Catches
   the mislabeled-industry fits **and** obvious non-fits that slipped the labels. No credits.
3. **T3 — ICP-driven web verification (PAID — the accuracy step).** The ICP's **proof signals are
   industry-agnostic and per-client** — derived in Step 0, *not* hardcoded. Examples by market: B2B SaaS →
   pricing / book-a-demo / "for teams"; manufacturer → product lines / plants / certifications; multi-site
   clinic group → # locations; agency → service pages / client logos; distributor → catalog / territories.
   Verify survivors via `serper` / `exa` / `firecrawl.scrape|map|extract` + `hyreflow_agent.infer` (prompt:
   `"Qualify company against ICP (with evidence)"`) → confirm fit + attach **evidence**. Accuracy-first → run it
   on the LLM-passed set (not just the ambiguous), gated by count-before-pay + the approval message.

→ Tier the output: **A** (verified + evidence) · **B** (likely, unverified) · **C** (maybe) · drop.

## STEP 4 — Deliver (the core output)
The ICP-fit company list: `name · domain · employee_size · industry · geo · _source · fit_tier · evidence`,
plus the **TAM size estimate** (Step 2) and a one-line "how to narrow (tighten filters) / expand (add a DB or
lookalikes)". Report the path + counts, not pasted rows.

## STEP 5 — OPTIONAL (opt-in): the relevant people
Ask **which people**: hiring managers, candidates, or both. Then per ICP-fit company:
- **Hiring managers** → company-scoped `people_search` (reporting-line-first / size-adaptive titles;
  `finding-companies-and-contacts.md`) → **work email** (`email_enrichment`).
- **Candidates** → company-scoped `people_search` by the target niche titles → **personal email + LinkedIn**
  (`personal_email`; never work email).
- Then **outreach** ([`campaign-plays.md`](campaign-plays.md)) and/or **push to the ATS**.
Reuses the `jd-to-shortlist` / `funding-to-bd` / `finding-companies-and-contacts` building blocks — this recipe just feeds them
a qualified company set.

---

## Tools by step
| Step | Tools |
|---|---|
| 0 ICP | `ICP.md` · ATS list methods (`recruit_crm.list_companies`, `recruiterflow.list_clients`, …) · CSV · `hyreflow_agent` (derive-ICP prompt) |
| 1A firmographic | **aiark** `company_search` · apollo · prospeo `search_company` · lusha (+ theirstack `catalog_industries` for LinkedIn-industry codes; builtwith only for who-uses-X breadth) |
| 1B people-first | `/search` people_search (aiark default) → company roll-up |
| 1C lookalike | prospeo `company_lookalike` · lusha/zoominfo `company_lookalikes` · predictleads `similar_companies` · exa `find_similar` |
| 2 count | each DB's total-count field (free peek) |
| 3 qualify | Model-A reasoning (free) + `serper`/`exa`/`firecrawl` + `hyreflow_agent` (paid web verify) |
| 5 people | company-scoped `people_search` → `email_enrichment` / `personal_email` → sequencer / ATS |

## New prompts (`prompts.json`)
- **"Derive ICP from seed accounts"** — companies[] (+ optional ATS fields) → `{industries[], size_band, geos[],
  tech[], keywords[], funding_stage?, exclusions[], proof_signals[] (industry-agnostic, web-checkable),
  fit_definition}`.
- **"Qualify company against ICP (with evidence)"** — company data + ICP (+ optional scraped web evidence) →
  `{fit_tier: A|B|C|no_fit, score, matched_signals[], missing[], evidence[], reason}`. Industry-agnostic.
- Reuse **"Research a company (agentic)"** for the Step-3 web fetch.

## Gates & caveats (honest)
- **Count-before-pay** — the TAM size is ~free; get it first.
- **Qualify before enrich** — never enrich non-fit companies.
- **Web verification is paid** → pilot one + approval message; accuracy-first but cost-aware.
- **Industry coverage:** the proof-signals are ICP-derived, so this works for any industry — but verification
  quality depends on the ICP being well-specified (Step 0 accuracy cascades down).
- **Coverage is a property of the market** — over-provision, deliver the complete rows, don't chase gaps.
- **Lookalike seed-verify**; **single-source-default** (fan out on demand); **EEO** on the people stage.
- **TAM ≠ hiring** — keep hiring/intent signals out of membership; they belong to outreach timing.
