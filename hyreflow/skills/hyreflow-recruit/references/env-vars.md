# hyreflow.ai — Environment variables

> **⚠️ ENGINE-OPERATOR doc — NOT for the agent.** These keys are set on the **server** that runs the
> Hyreflow engine (the managed credit system, or a client's own BYOK config). **The agent never sets
> or needs these locally.** As an agent you call `hyreflow tools execute <provider>_<method>` and the
> engine resolves the key server-side — do NOT grep your env for these, do NOT call a vendor directly.
> See SKILL.md → "Execution model". This table exists so whoever operates the engine knows what to set.

Every adapter (in the engine) reads its credentials from the environment. **Never hardcode a key; never
commit one.** The engine operator sets these in the server's secrets manager / environment.

| Tool | Env var(s) | Auth scheme | Notes |
|---|---|---|---|
| aiark | `AIARK_API_KEY` | header `X-TOKEN` | paths inferred from doc slugs — verify on first pilot |
| aircall | `AIRCALL_API_ID`, `AIRCALL_API_TOKEN` | HTTP Basic (id:token) | partner multi-co apps use OAuth (not in adapter) |
| apify | `APIFY_API_KEY` | Bearer | actorId = `username~actorname` |
| apollo | `APOLLO_API_KEY` | header `x-api-key` | BYOK-only for user workspaces; no managed fallback for workspace calls; page/per_page |
| bettercontact | `BETTERCONTACT_API_KEY` | header `X-API-Key` | async: start job → poll |
| bullhorn | `BULLHORN_CLIENT_ID`, `BULLHORN_CLIENT_SECRET`, `BULLHORN_USERNAME`, `BULLHORN_PASSWORD`, `BULLHORN_REDIRECT_URI` | 3-leg OAuth → BhRestToken | redirect_uri must match the OAuth app |
| enrichley | `ENRICHLEY_API_KEY` | header `x-api-key` | email validation |
| exa | `EXA_API_KEY` | header `x-api-key` | |
| fathom | `FATHOM_API_KEY` | header `X-Api-Key` | user-scoped; cursor pagination |
| firecrawl | `FIRECRAWL_API_KEY` | Bearer | also used by the doc-scraper tooling |
| fullenrich | `FULLENRICH_API_KEY` | Bearer | async: start → poll |
| heyreach | `HEYREACH_API_KEY` | header `X-API-KEY` | verify path casing on pilot |
| icypeas | `ICYPEAS_API_KEY` | header `Authorization` | optional HMAC-signing variant |
| instantly | `INSTANTLY_API_KEY` | Bearer | cursor pagination (`starting_after`) |
| leadmagic | `LEADMAGIC_API_KEY` | header `X-API-Key` | |
| lemlist | `LEMLIST_API_KEY` | HTTP Basic (`'' : key`) | paths mapped from slugs — verify |
| loxo | `LOXO_API_KEY`, `LOXO_DOMAIN`, `LOXO_AGENCY_SLUG` | Bearer | agency-scoped base URL; DOMAIN e.g. `agency.app.loxo.co` |
| lusha | `LUSHA_API_KEY` | header `api_key` | |
| prospeo | `PROSPEO_API_KEY` | header `X-KEY` | enrich/search/suggestions live-confirmed |
| recruit_crm | `RECRUITCRM_API_KEY` | Bearer | 35 methods; full CRUD |
| recruiterflow | `RECRUITERFLOW_API_KEY` | header `RF-Api-Key` | |
| serper | `SERPER_API_KEY` | header `X-API-KEY` | google.serper.dev + scrape.serper.dev |
| smartlead | `SMARTLEAD_API_KEY` | **query param** `api_key` | not a header |
| theirstack | `THEIRSTACK_API_KEY` | `Authorization: Bearer` | credits: jobs 1/result, companies 3/result; blur_company_data=free preview |
| predictleads | `PREDICTLEADS_API_KEY`, `PREDICTLEADS_API_TOKEN` | headers `X-Api-Key` + `X-Api-Token` (**inferred — verify**) | funding/hiring discovery; JSON:API; base `/api/v3`; company endpoints per-request (≤1000), discover per-result; paths/auth flagged verify-on-pilot |
| shovels | `SHOVELS_API_KEY` | header `X-API-Key` | US building permits + contractors; cursor pagination; credit-metered; searches need geo_id+permit_from/to |
| github | `GITHUB_TOKEN` | `Authorization: Bearer` (PAT) | dev sourcing; REST 5k/hr, Search 30/min + 1000 cap; emails public-only → enrich downstream |
| clinicaltrials | **none** | **no auth (public API)** | pharma/biotech hiring signals; pageToken pagination; signal detection = recipe (diff snapshots) |
| layoffsignal | **none** (Hyreflow **Native**) | **no auth** (free public RSS) | layoff/RIF recruiting trigger; credit-metered, NO BYOK key; Google News RSS + per-site feeds; links via firecrawl |
| builtwith | `BUILTWITH_API_KEY` | **`KEY` query param** | technographics; versioned per-API paths; credit/quota-metered; Lists is heavy (OFFSET paging) |
| zoominfo | `ZOOMINFO_CLIENT_ID`, `ZOOMINFO_CLIENT_SECRET` (+ optional `ZOOMINFO_SCOPE`) | OAuth2 client-credentials → Bearer | token `POST /gtm/oauth/v1/token` (~1h, auto-refreshed); per-endpoint scopes (api:data:contact/company…); credit-metered |
| sourcewhale | `SOURCEWHALE_API_KEY`, `SOURCEWHALE_USER_EMAIL` | header (confirm) | auth scheme flagged to confirm |
| vincere | `VINCERE_TENANT`, `VINCERE_API_KEY`, `VINCERE_ID_TOKEN` | `x-api-key` + `id-token` | id_token ~30 min TTL — refresh via OAuth |

**Parked (no env / no adapter):** `quil` (CoRecruit) — no public API.

## Keys to rotate
The Firecrawl keys and Instantly key pasted in chat during the build **must be rotated** — treat any
key that has touched a chat transcript as compromised.
