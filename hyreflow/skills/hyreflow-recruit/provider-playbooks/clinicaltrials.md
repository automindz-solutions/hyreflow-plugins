---
name: clinicaltrials
description: "Pharma/biotech/CRO hiring signals via the ClinicalTrials.gov v2 API — search clinical trials by sponsor/condition/status/phase, track recruiting-status and phase transitions, site/country expansion, and sponsor/CRO growth. Use when sourcing or doing BD in pharma, biotech, medical devices, CROs, or clinical research — trial activity predicts hiring before jobs are posted. No API key (free public API)."
---

# ClinicalTrials.gov — Integration Meta Skill (pharma hiring signals)

HOW in `lib/clinicaltrials.py`. Index: `reference/docs/clinicaltrials/raw/endpoints.md`.

## Auth & config
- **Base:** `https://clinicaltrials.gov/api/v2` · **No authentication — free public API** (no env var needed).
- **Pagination:** `pageSize` (≤1000) + `pageToken` → `nextPageToken`; `iter_studies(max_studies=…)` auto-walks it. List params (`filter.overallStatus`, `fields`, `sort`) are comma-joined for you. Use `fields=RECRUITER_FIELDS` to keep responses compact.

## Operations
Search: `search_studies` / `iter_studies` (query.cond/term/spons/lead/intr/locn + filter.overallStatus/advanced/ids/geo). Convenience: `search_by_sponsor`, `recruiting_studies`, `recently_updated(since)` (the daily signal pull — `AREA[LastUpdatePostDate]RANGE[since,MAX]`). Single: `get_study(nct_id)` (json/csv/fhir.json/ris). Reference: `studies_metadata`, `search_areas`, `enums`, `field_values`, `stats_size`, `version`.

## Query syntax (Essie) — avoid 400/422s & bad results
`query.*` and `filter.advanced` use **Essie expression syntax**. **Full operator reference cached at
`reference/docs/clinicaltrials/raw/search-syntax.md`.** Essentials:
- **Booleans UPPERCASE** — `AND` / `OR` / `NOT` (NOT is unary). Group with `()`; phrase with `"…"`. Ex: `(head OR neck) AND NOT pain`.
- **Target a field:** `AREA[Field]value` — `AREA[Phase]PHASE3`, `AREA[LeadSponsorClass]INDUSTRY`, `AREA[InterventionName]aspirin`.
- **RANGE:** `AREA[StartDate]RANGE[2024-01-01,MAX]`, `AREA[LastUpdatePostDate]RANGE[2026-05-01,MAX]` (`MIN`/`MAX` open ends; won't match records missing the value).
- **Default EXPANSION is `Relaxation` = fuzzy** (`heart disease` also matches "heart and lung disease"). For precise matches use `EXPANSION[None]` or `COVERAGE[FullMatch]`.
- **`SEARCH[Location](…)` gotcha:** to require a US site that is *itself* recruiting → `SEARCH[Location](AREA[LocationCountry]United States AND AREA[LocationStatus]Recruiting)`. Without it, the US site and the recruiting site can be different facilities. (Different from study-level `filter.overallStatus=RECRUITING`.)
- Also: `MISSING`, `DISTANCE[lat,lon,25mi]`, `ALL`, `TILT[DateField]`. Escape an operator as a term with `\` (e.g. `\MISSING`).

**Use ENUM values, not labels** (#1 cause of 4xx): `filter.overallStatus=RECRUITING` (not "Recruiting"); `AREA[Phase]PHASE3` (not "Phase 3"); `LeadSponsorClass` ∈ {INDUSTRY, NIH, FED, OTHER_GOV, INDIV, NETWORK, OTHER, …}. **Don't guess field names or enum values — discover them from the API:** `search_areas()` (field→param), `enums()` (valid enum values), `studies_metadata()` (all field names for `fields`/`sort`/`AREA[]`).

**Paging:** subsequent pages repeat the SAME params except `countTotal`/`pageSize`/`pageToken` (handled by `iter_studies`). If a `query.*` param contains ONLY NCT IDs, filters are ignored. List params are comma/pipe-separated (adapter joins lists). `query.*` affects ranking; `filter.*` does not.

## Why it's here — the signal model (the product angle)
"Pharma Hiring Signals," not "trial monitoring." A trial can't start/expand/advance without people, so trial events predict hiring **before** a job is posted. Detect these events and map to job families:

| Event (detected by diffing snapshots over time) | Likely roles |
|---|---|
| New trial started | CRA, Clinical Trial/Project/Operations Manager, Data Manager |
| Phase I→II | CRA, Clinical Ops, Regulatory Affairs, Data Mgmt (2–10× scale-up) |
| **Phase II→III (strongest)** | Senior CRA, Clinical Trial Manager, Regulatory, Biostatistician, Medical Monitor |
| NOT_YET_RECRUITING→RECRUITING | hiring happens right before/at this transition |
| +sites / +country | (Senior) CRA, Site/Regional Managers, Regulatory |
| Sponsor trial-count growth / CRO study wins | Clinical Ops, Program Managers, Medical Affairs |

A simple hiring-score (e.g. Phase II→III +50, recruiting +25, +50 sites +40, new country +20) ranks sponsors.

## ⚠️ Important: signals need state, not one call
Phase transitions / +sites / status flips are **changes over time** — they require pulling trials (e.g. `recently_updated` daily) and **diffing against a stored snapshot**. That detection + scoring + job-family mapping is a **recipe** (agent-side, Model A), not a single endpoint. This adapter is the data layer that feeds it.

## Handoff
Signal layer (pharma/biotech): detect trial event → map to job families → **enrich the sponsor/CRO decision-makers** (waterfall) → qualify vs ICP → outreach/ATS. A far stronger outbound trigger than "saw you hiring on LinkedIn" because it's tied to the underlying business event that created the need.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute clinicaltrials <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get clinicaltrials <method>` returns the live contract + cost). Base: `https://clinicaltrials.gov/api/v2`. Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `enums() -> Any` — GET /studies/enums — enum types + values (e.g. OverallStatus, Phase).
- `field_values(**params) -> Any` — GET /stats/field/values — value stats for leaf fields (types, fields).
- `get_study(nct_id: str, **params) -> Any` — GET /studies/{nctId} — single study. format: json|csv|json.zip|fhir.json|ris; fields (json).
- `iter_studies(*, max_studies: int = 1000, **params) -> Iterator[dict]` — Auto-paginate /studies via nextPageToken (bounded by max_studies).
- `recently_updated(since: str, *, fields: list[str] | None = None, **params) -> Any` — Studies updated on/after `since` (YYYY-MM-DD) — the daily signal pull. Uses query.term=AREA[LastUpdatePostDate]RANGE[since,MAX], sorted newest-first.
- `recruiting_studies(*, condition: str | None = None, sponsor: str | None = None, fields: list[str] | None = None, **params) -> Any` — Currently-recruiting studies (filter.overallStatus=RECRUITING) — active hiring demand.
- `search_areas() -> Any` — GET /studies/search-areas — searchable areas + their query params.
- `search_by_sponsor(sponsor: str, *, status: list[str] | str | None = None, fields: list[str] | None = None, **params) -> Any` — Studies for a sponsor/collaborator (query.spons). Optional overallStatus filter + compact fields.
- `search_studies(**params) -> Any` — GET /studies — one page. Params: query.cond/term/locn/titles/intr/outc/spons/lead/id/patient (Essie syntax); filter.overallStatus (list), filter.advanced, filter.ids, filter.geo; fields (list), sort (≤2), pageSize (≤1000), countTotal, pageToken. Returns {totalCount?, studies:[...], nextPageToken?}.
- `stats_size() -> Any` — GET /stats/size — study JSON size statistics.
- `studies_metadata(**params) -> Any` — GET /studies/metadata — the data-model field list (includeIndexedOnly, includeHistoricOnly).
- `version() -> Any` — GET /version — API + data version (safe read-only pilot).

<!-- API-SURFACE:END -->
