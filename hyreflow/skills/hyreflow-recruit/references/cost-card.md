# hyreflow — cost card (credit costs per operation)

Auto-generated — do not edit by hand.

Per-operation **credit costs**, resolved from Hyreflow's pricing source of truth (every method carries a `cost` `{credits, unit, note}`).

> **Pricing model:** 1 credit ≈ **$0.10** (reference managed rate). **BYOK = free** — you pay the provider directly, zero Hyreflow cost. Top-up credits are priced above the managed rate — bigger top-ups cost less per credit.

## How pricing works

Each method is priced on its own: what the call costs Hyreflow, marked up to a 50% margin floor and rounded up to the nearest 0.1 credit. Paid methods run from **0.05 credit** to **13.9 credits**, and a cheaper provider is a cheaper call: the waterfalls try the low-cost providers first. Read a method's exact price from its `cost` block in the tool registry rather than memorising a number.

| Billing mode | What you pay |
|---|---|
| paid | 0.05–13.9 credits, charged per result returned, per request, or per page, and each method states which |
| free | 0 credits: account, catalog, ping and masked-preview calls |
| byok | 0 credits: add your own vendor key and the call runs on your account |
| metered | provider-metered, no fixed per-action price |
| argument-priced | more for more: revealing a mobile costs more than an email. `credits_max` is the worst case |

## Per-tool paid-method highlights

| Tool | Cheapest paid op | Priciest paid op | Notes |
|---|---|---|---|
| aiark | `company_search` 0.1 cr | `reverse_lookup` 1.4 cr | 9 paid methods |
| aircall | free | free | No Hyreflow credits for any method. |
| apify | metered | metered | BYOK-only: customer pays Apify directly |
| apollo | metered | metered | BYOK-only: customer pays Apollo directly |
| atlas | metered | metered | BYOK-only: customer connects their own Atlas account |
| bettercontact | `start_enrichment` 0.5 cr | `start_enrichment` 0.5 cr | 1 paid method |
| builtwith | metered | metered | BYOK-only: customer pays BuiltWith directly |
| bullhorn | free | free | No Hyreflow credits for any method. |
| clinicaltrials | free | free | No Hyreflow credits for any method. |
| enrichley | `validate_email` 0.25 cr | `validate_email` 0.25 cr | 1 paid method |
| exa | `answer` 0.1 cr | `start_agent_run` 0.5 cr | 5 paid methods |
| fathom | metered | metered | BYOK-only: customer connects their own Fathom account |
| firecrawl | `map` 0.1 cr | `start_crawl` 0.1 cr | 4 paid methods |
| fullenrich | `search_company` 0.4 cr | `start_mobile_enrichment` 12.6 cr | 5 paid methods |
| github | free | free | No Hyreflow credits for any method. |
| granola | metered | metered | BYOK-only: customer connects their own Granola account |
| heyreach | metered | metered | BYOK-only: customer connects their own HeyReach account |
| hyreflow_agent | metered | metered | Provider-metered — no fixed per-action price. |
| hyreflow_native | `get_arbeitsagentur_jobs` 0.05 cr | `search_posts` 0.2 cr | 7 paid methods |
| icypeas | `email_verification` 0.1 cr | `email_search` 0.5 cr | 3 paid methods |
| instantly | metered | metered | BYOK-only: customer connects their own Instantly account |
| jobadder | free | free | No Hyreflow credits for any method. |
| layoffsignal | free | free | No Hyreflow credits for any method. |
| leadmagic | `employee_finder` 0.1 cr | `b2b_profile` 5.5 cr | 13 paid methods |
| lemlist | metered | metered | BYOK-only: customer connects their own Lemlist account |
| loxo | metered | metered | BYOK-only: customer connects their own Loxo account |
| lusha | `company_lookalikes` 2.8 cr | `search_and_enrich_contact_phones` 13.9 cr | 17 paid methods |
| predictleads | `company` 0.8 cr | `technologies` 2.4 cr | 28 paid methods |
| prospeo | `search_suggestions` 0.1 cr | `mobile_finder` 3.4 cr | 12 paid methods |
| recruit_crm | metered | metered | BYOK-only: customer connects their own Recruit CRM account |
| recruiterflow | metered | metered | BYOK-only: customer connects their own Recruiterflow account |
| sendkit | metered | metered | BYOK-only: customer connects their own SendKit account |
| serper | `autocomplete` 0.1 cr | `search` 0.1 cr | 9 paid methods |
| shovels | metered | metered | BYOK-only: customer pays Shovels directly |
| smartlead | metered | metered | BYOK-only: customer connects their own Smartlead account |
| sourcewhale | metered | metered | BYOK-only: customer connects their own SourceWhale account (API key + user email) |
| spott | metered | metered | BYOK-only: customer connects their own Spott account |
| theirstack | `search_jobs` 0.9 cr | `search_companies` 2.7 cr | 4 paid methods |
| vincere | free | free | No Hyreflow credits for any method. |
| wiza | `create_list` 1.0 cr | `start_individual_reveal` 1.0 cr | 5 paid methods |
| zoominfo | metered | metered | BYOK-only: customer pays ZoomInfo directly |

## Full per-method rate card

For the complete generated table, see the Pricing Tables doc on the Hyreflow site.

## Cheapest-first enrichment orders

Waterfalls are ordered cheap → expensive and stop at the first hit, so you pay one provider per row. Exact ordering is derived from the current cost card at runtime; do not hardcode it here.

## Why a miss can cost more than a hit

The search waterfall stops at the first provider that fills the quota, so a query that hits settles on one cheap step near the front of the chain. A query that finds nobody walks the whole chain instead, and the per-request web fallbacks at the end of it charge for running the search regardless of what comes back. Budget a sizing pass over long-tail or sparsely-indexed companies well above the per-hit rate, not at it.