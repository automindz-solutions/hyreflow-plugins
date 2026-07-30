# hyreflow — cost card (credit costs per operation)

Auto-generated — do not edit by hand.

Per-operation **credit costs**, resolved from Hyreflow's pricing source of truth (every method carries a `cost` `{credits, unit, note}`).

> **Pricing model:** 1 credit ≈ **$0.10** (reference managed rate). **BYOK = free** — you pay the provider directly, zero Hyreflow cost. Volume discounts apply at 1,000+ credits.

## flat credit tiers

| Tier | Credits | Notes |
|---|---|---|
| **free** | 0 | No charge — account/catalog/search-preview or BYOK/free-to-us |
| **micro** | 0.5 | 0.5 credits — verification, web, scrape, search |
| **standard** | 3 | 3 credits — email finder, person/company/jobs/technographics data |
| **premium** | 5 | 5 credits — personal email, reverse lookup, lookalikes, funding |
| **phone** | 10 | 10 credits — mobile/phone and premium-profile data |
| **native** | 0.05 | 0.05 credits — native job scraper per job delivered |
| **runtime** | 0 | Usage/runtime-based pass-through (Apify, Exa) |
| **metered** | varies | Provider-metered / no fixed per-action price |

## Per-tool paid-method highlights

| Tool | Cheapest paid op | Priciest paid op | Notes |
|---|---|---|---|
| aiark | `company_search` 3 cr | `mobile_phone_finder` 10 cr | 9 paid methods |
| aircall | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| apify | metered | metered | No charge — account/catalog/search-preview or BYOK/free-to-us |
| apollo | metered | metered | BYOK-only — customer pays Apollo directly |
| atlas | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| bettercontact | `start_enrichment` 3 cr | `start_enrichment` 3 cr | 1 paid method |
| builtwith | metered | metered | BYOK-only — customer pays BuiltWith directly |
| bullhorn | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| clinicaltrials | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| enrichley | `validate_email` 0.5 cr | `validate_email` 0.5 cr | 1 paid method |
| exa | metered | metered | $5/1k answers |
| fathom | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| firecrawl | `map` 0.5 cr | `start_crawl` 0.5 cr | 4 paid methods |
| fullenrich | `search_company` 3 cr | `start_reverse_email` 5 cr | 3 paid methods |
| github | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| granola | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| heyreach | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| hyreflow_agent | metered | metered | No charge — account/catalog/search-preview or BYOK/free-to-us |
| hyreflow_native | `get_arbeitsagentur_jobs` 0.05 cr | `get_linkedin_jobs` 0.05 cr | 4 paid methods |
| icypeas | `domain_search` 0.5 cr | `email_search` 3 cr | 3 paid methods |
| instantly | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| jobadder | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| layoffsignal | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| leadmagic | `email_validation` 0.5 cr | `mobile_finder` 10 cr | 13 paid methods |
| lemlist | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| loxo | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| lusha | `company_signals` 3 cr | `contact_lookalikes` 5 cr | 14 paid methods |
| predictleads | `discover_news_events` 0.5 cr | `similar_companies` 5 cr | 27 paid methods |
| prospeo | metered | metered | No charge — account/catalog/search-preview or BYOK/free-to-us |
| recruit_crm | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| recruiterflow | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| serper | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| shovels | metered | metered | BYOK-only — customer pays Shovels directly |
| smartlead | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| sourcewhale | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| theirstack | `company_buying_intents` 3 cr | `search_jobs` 3 cr | 4 paid methods |
| vincere | free | free | No charge — account/catalog/search-preview or BYOK/free-to-us |
| wiza | `create_list` 3 cr | `start_individual_reveal` 3 cr | 5 paid methods |
| zoominfo | metered | metered | BYOK-only — customer pays ZoomInfo directly |

## Full per-method rate card

For the complete generated table, see the Pricing Tables doc on the Hyreflow site.

## Cheapest-first enrichment orders

Waterfalls are ordered cheap → expensive and stop at the first hit, so you pay one provider per row. Exact ordering is derived from the current cost card at runtime; do not hardcode it here.