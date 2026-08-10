# hyreflow — cost card (credit costs per operation)

Auto-generated — do not edit by hand.

Per-operation **credit costs**, resolved from Hyreflow's pricing source of truth (every method carries a `cost` `{credits, unit, note}`).

> **Pricing model:** 1 credit ≈ **$0.10** (reference managed rate). **BYOK = free** — you pay the provider directly, zero Hyreflow cost. Volume discounts apply at 1,000+ credits.

## How pricing works

Each method is priced on its own: what the call costs Hyreflow, marked up to a 70% margin floor and rounded up to the nearest 0.1 credit. Paid methods run from **0.05 credit** to **9.2 credits**, and a cheaper provider is a cheaper call — the waterfalls try the low-cost providers first. Read a method's exact price from its `cost` block in the tool registry rather than memorising a number.

| Billing mode | What you pay |
|---|---|
| paid | 0.05–9.2 credits, per returned record or per call (see `unit`) |
| free | 0 credits — account, catalog, ping and masked-preview calls |
| byok | 0 credits — add your own vendor key and the call runs on your account |
| metered | provider-metered, no fixed per-action price |
| argument-priced | more for more: revealing a mobile costs more than an email. `credits_max` is the worst case |

## Per-tool paid-method highlights

| Tool | Cheapest paid op | Priciest paid op | Notes |
|---|---|---|---|
| aiark | `company_search` 0.1 cr | `reverse_lookup` 2.4 cr | 9 paid methods |
| aircall | free | free | No Hyreflow credits for any method. |
| apify | metered | metered | BYOK-only — customer pays Apify directly |
| apollo | metered | metered | BYOK-only — customer pays Apollo directly |
| atlas | free | free | No Hyreflow credits for any method. |
| bettercontact | `start_enrichment` 0.8 cr | `start_enrichment` 0.8 cr | 1 paid method |
| builtwith | metered | metered | BYOK-only — customer pays BuiltWith directly |
| bullhorn | free | free | No Hyreflow credits for any method. |
| clinicaltrials | free | free | No Hyreflow credits for any method. |
| enrichley | `validate_email` 0.4 cr | `validate_email` 0.4 cr | 1 paid method |
| exa | metered | metered | Provider-metered — no fixed per-action price. |
| fathom | free | free | No Hyreflow credits for any method. |
| firecrawl | `map` 0.1 cr | `start_crawl` 0.1 cr | 4 paid methods |
| fullenrich | `search_company` 0.6 cr | `start_reverse_email` 2.1 cr | 3 paid methods |
| github | free | free | No Hyreflow credits for any method. |
| granola | free | free | No Hyreflow credits for any method. |
| heyreach | free | free | No Hyreflow credits for any method. |
| hyreflow_agent | metered | metered | Provider-metered — no fixed per-action price. |
| hyreflow_native | `get_arbeitsagentur_jobs` 0.05 cr | `get_linkedin_jobs` 0.05 cr | 4 paid methods |
| icypeas | `email_verification` 0.1 cr | `email_search` 0.8 cr | 3 paid methods |
| instantly | free | free | No Hyreflow credits for any method. |
| jobadder | free | free | No Hyreflow credits for any method. |
| layoffsignal | free | free | No Hyreflow credits for any method. |
| leadmagic | `employee_finder` 0.1 cr | `b2b_profile` 9.2 cr | 13 paid methods |
| lemlist | free | free | No Hyreflow credits for any method. |
| loxo | free | free | No Hyreflow credits for any method. |
| lusha | `company_lookalikes` 4.6 cr | `prospecting_contacts` 9.2 cr | 14 paid methods |
| predictleads | `company` 1.4 cr | `technologies` 4.0 cr | 28 paid methods |
| prospeo | `bulk_enrich_company` 0.6 cr | `mobile_finder` 5.6 cr | 10 paid methods |
| recruit_crm | free | free | No Hyreflow credits for any method. |
| recruiterflow | free | free | No Hyreflow credits for any method. |
| serper | free | free | No Hyreflow credits for any method. |
| shovels | metered | metered | BYOK-only — customer pays Shovels directly |
| smartlead | free | free | No Hyreflow credits for any method. |
| sourcewhale | free | free | No Hyreflow credits for any method. |
| theirstack | `search_jobs` 1.5 cr | `search_companies` 4.5 cr | 4 paid methods |
| vincere | free | free | No Hyreflow credits for any method. |
| wiza | `create_list` 1.7 cr | `start_individual_reveal` 1.7 cr | 5 paid methods |
| zoominfo | metered | metered | BYOK-only — customer pays ZoomInfo directly |

## Full per-method rate card

For the complete generated table, see the Pricing Tables doc on the Hyreflow site.

## Cheapest-first enrichment orders

Waterfalls are ordered cheap → expensive and stop at the first hit, so you pay one provider per row. Exact ordering is derived from the current cost card at runtime; do not hardcode it here.