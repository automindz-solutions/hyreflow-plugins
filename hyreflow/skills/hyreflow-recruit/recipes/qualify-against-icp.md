# Recipe — Qualify companies against the client's ICP (the qualification gate)

**Use when:** a sourcing step produced a set of companies (LinkedIn/job scrape, people/company search,
an uploaded list) and you're about to spend credits enriching or sequencing. Run this gate **first** so
only ICP-fit companies pass downstream. This is the `qualify` stage of the pipeline:
`source → qualify(ICP) → enrich → sequence → CRM`.

## Where this runs (Model A)
Qualification is **reasoning done by the host agent** (the agent running this skill), reading
the client's local `ICP.md`. **No hyreflow server call, no hosted AI model call, no credits for the judgment itself**
— credits are only spent on the optional firmographic lookups in Step 1 and on enriching the *passes*.

## Inputs
- `companies` — from the sourcing step; each ideally carries `name`, `domain`/`website`, and any
  firmographics the source already returned (industry, size, location, the job context).
- `ICP.md` — the client's Ideal Customer Profile, built by **`/icp`** and stored in the working directory
  (per-client **data**, not part of this skill). If it's missing, tell the user to run `/icp` first; do
  not silently skip the gate.

## Step 1 — Hard filters (data rules, NO LLM, ~free)
Read the firmographic constraints from `ICP.md` (Industry, Company Type, Stage & Size, Geography, and any
explicit exclusions) and apply them to the data you **already have** from the sourcing step:
- Drop companies clearly outside geo / size band / industry / type / exclusions.
- Use fields already present first (job + people-search payloads usually carry company industry, size,
  location). Only if a *decisive* hard-filter field is missing do you fetch it with one cheap company
  enrich — and flag the spend: `Apollo().enrich_organization(domain)`, `AiArk().company_search({...})`,
  `Lusha().enrich_company(domain=…)`, `ZoomInfo().enrich_companies({...})`, or a LeadMagic company enrich.
  Batch where the adapter supports it.
- Output: survivors → Step 2; dropped → log with the failing rule.

## Step 2 — Fuzzy fit (LLM judgment = the host agent, free)
For survivors, judge qualitative fit against `ICP.md`'s signals (mission, product, buyer, "what good
looks like"). Pick the path by scale:
- **Inline (small N):** you (the agent) read each company's site/description + `ICP.md` and assign a fit
  **tier (A/B/C)** or **score (0–100)** with a one-line reason.
- **At scale / parallel:** dispatch the **`company-qualifier`** agent (it WebFetches each site and scores
  against a qualification prompt). First derive that weighted qualification prompt from `ICP.md`; the
  **`icp-analysis`** framework / **`icp-analyzer`** agent define the dimensions.
- **Threshold:** default keep tier **A/B** (or **score ≥ 70**); make it configurable per client in `ICP.md`.

## Output
- `qualified` — fits (with score + reason) → proceed to enrich → verify → sequence → CRM.
- `rejected` — non-fits, logged with reasons (so the user can audit what was dropped and why).

Only `qualified` companies move forward — that is the credit-saver.

## Where it sits in the pipeline
```
source (jobs/people/list) → [qualify-against-icp] → enrich → verify → sequence → CRM
                                  ↑ reads client-local ICP.md
```
Always run the gate **before** enrichment/outreach, never after — the whole point is to not pay to
enrich or sequence non-fits.

## Cost discipline (three nested funnels)
1. Hard filters (free, on data you already have) shrink the set.
2. LLM fuzzy-fit runs only on survivors (free — host agent).
3. Enrichment runs only on the passes (credits).
Keeps both LLM and API/credit cost minimal.

## Notes
- **No new adapter, no hyreflow server call** — pure agent reasoning + the existing `/icp`,
  `icp-analysis`, `company-qualifier`, `icp-analyzer` assets (all customer-side).
- `ICP.md` is per-client data kept in the client's workspace — keep it **out of** the `hyreflow.ai/` skill.
- Reuse: every sourcing flow (jobs→managers, list-building, inbound) routes through this same gate.
