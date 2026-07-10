# hyreflow — cost card (credit costs per operation)

Per-operation **credit costs**, **a managed-credit rate card (2026-06-01)** for the tools
we also have. Source of truth = `reference/cost-card.json`; merged into `reference/tool-registry.json`
(every method carries a `cost` `{credits, unit, note}`). Re-run `python reference/_gen_tool_registry.py`
after editing the cost card.

> **Pricing model (copied):** 1 credit ≈ **$0.10** (reference managed rate; **hyreflow's own retail
> $/credit is still TBD** — see memory `project_hyreflow_pricing_deferred`). **BYOK = free** (client pays
> the provider directly, zero hyreflow cost). Credits ≈ underlying provider rate + a small platform fee.

## The structural pattern (worth keeping for hyreflow's own model)
- **FREE:** every `search`/`autocomplete`/`check-credits`/preview, **all sequencers** (instantly, lemlist,
  heyreach, smartlead, sourcewhale), and **ATS/CRM writes** (recruit-crm, loxo, vincere, recruiterflow, bullhorn).
- **CHARGED:** only the **data reveals** — email/phone finds, person/company enrichment.
- **`apollo` = BYOK-only** (not resold on managed credits).
- **Waterfalls stop at first hit** → you pay one provider, not all of them. Order them cheap→expensive.

## Per-tool highlights (credits; full per-method list is in the registry `cost` field)
| Tool | Cheapest charged op | Pricier ops |
|---|---|---|
| aiark | company_search 0.02, people_search/find_emails 0.07 | people_analysis 0.56, mobile_phone_finder 0.70 |
| theirstack | search_jobs 0.02 (preview free) | search_companies / technographics 0.05 |
| serper | search 0.02 | maps 0.04 |
| exa | get_contents 0.02 | answer/search 0.07; agent runs usage-metered on your own account (no fixed price) |
| firecrawl | scrape/map/crawl 0.02 | search 0.03; extract = runtime |
| builtwith | lists/trends/free **0**! | domain/keywords/vector_search/relationships 0.14 |
| icypeas | email_verification 0.02 | email/domain search 0.14 |
| leadmagic | employee_finder 0.02, email_validation 0.09 | personal_email 0.68, mobile 1.68 |
| prospeo | enrich/search 0.55 (flat) | — |
| lusha | enrich/search 0.70 (flat) | — |
| fullenrich | company search 0.21 | bulk enrich = billed on result |
| bettercontact | — | enrich = billed on result |
| apollo | **BYOK (free on hyreflow)** | BYOK |

**No copied reference (provider-metered — verify before bulk):** `zoominfo`, `shovels`, `enrichley`,
and the prospeo/leadmagic/theirstack methods not on the reference card. **Runtime/usage-based:** `apify`,
firecrawl `extract`. **Native (hyreflow credit, cost TBD):** `layoffsignal`. **Free public:** `github`,
`clinicaltrials`.

## Cheapest-first enrichment orders (cost-aware, matches provider-precedence)
- **work email:** aiark find_emails 0.07 → icypeas 0.14 → leadmagic 0.34 → prospeo 0.55 → lusha 0.70
- **personal email:** **leadmagic** personal 0.68 → **fullenrich** `contact.personal_emails` (3 cr) — the two personal-email sources (COO-confirmed) + engineers: GitHub commit-email (free). prospeo/aiark/bettercontact = work email only.
- **mobile/phone:** aiark 0.70 → leadmagic 1.68 (phones are the expensive reveal — gate hard)
- **company enrich:** aiark 0.02 → theirstack 0.05 → fullenrich 0.21 → prospeo 0.55 → lusha 0.70
