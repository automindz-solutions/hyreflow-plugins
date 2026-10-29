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
| aircall | `AIRCALL_API_ID`, `AIRCALL_API_TOKEN` | HTTP Basic (id:token) | partner multi-co apps use OAuth (not in adapter); BYOK-only; the customer connects it themselves on the Integrations page (API ID + API Token) |
| apify | `APIFY_API_KEY` | Bearer | BYOK-only for user workspaces; no managed fallback for workspace calls; actorId = `username~actorname` |
| apollo | `APOLLO_API_KEY` | header `x-api-key` | BYOK-only for user workspaces; no managed fallback for workspace calls; page/per_page |
| ashby | `ASHBY_API_KEY` | HTTP Basic (key as username) | ATS job posting; needs the vendor's `jobsWrite` permission; connect-your-own (BYOK, self-serve) |
| atlas | `ATLAS_API_KEY` | `Authorization: Bearer` | AI-native ATS/CRM; 30 methods; long tail via `request()`; connect-your-own (BYOK, self-serve) |
| bettercontact | `BETTERCONTACT_API_KEY` | header `X-API-Key` | async: start job → poll |
| breezy | `BREEZY_API_KEY`, `BREEZY_COMPANY_ID` | header `Authorization` (RAW token, **no** `Bearer` prefix) | ATS job posting; company id is a path segment; BYOK-only, **not self-serve — coming soon** while the vendor finishes its v3 API |
| bullhorn | `BULLHORN_CLIENT_ID`, `BULLHORN_CLIENT_SECRET`, `BULLHORN_USERNAME`, `BULLHORN_PASSWORD` (+ optional `BULLHORN_REDIRECT_URI`) | loginInfo → 3-leg OAuth → BhRestToken | datacenter hosts resolved per username via loginInfo; leave redirect_uri unset unless the OAuth app needs it; BYOK-only, self-serve (connect your own API user) |
| carerix | `CARERIX_CLIENT_ID`, `CARERIX_CLIENT_SECRET`, `CARERIX_TENANT` | OAuth client credentials → `Authorization: Bearer <token>` | BYOK-only, self-serve (Integrations → Carerix: Client ID + Client Secret + tenant name; tenants on a non-default identity host are not supported yet); the token is fetched and refreshed for you |
| emailbison | `EMAILBISON_API_KEY`, `EMAILBISON_BASE_URL` | `Authorization: Bearer` | one instance per customer: the instance URL (https) is part of the credential; `api-user` token from Settings → Developer API; connect-your-own (BYOK, self-serve) |
| crelate | `CRELATE_API_KEY` | header `X-Api-Key` | BYOK-only, self-serve (Integrations → Crelate: paste the API key from Crelate's Your Profile & Preferences → API Access); the key acts as the user who created it; paced at 100 requests/minute |
| enrichley | `ENRICHLEY_API_KEY` | header `x-api-key` | email validation |
| exa | `EXA_API_KEY` | header `x-api-key` | |
| fathom | `FATHOM_API_KEY` | header `X-Api-Key` | user-scoped; cursor pagination; connect-your-own (BYOK, self-serve) |
| firecrawl | `FIRECRAWL_API_KEY` | Bearer | also used by the doc-scraper tooling |
| fullenrich | `FULLENRICH_API_KEY` | Bearer | async: start → poll |
| heyreach | `HEYREACH_API_KEY` | header `X-API-KEY` | verify path casing on pilot; connect-your-own (BYOK, self-serve) |
| icypeas | `ICYPEAS_API_KEY`, `ICYPEAS_ACCOUNT_EMAIL` | header `Authorization` | wrong account email 401s |
| instantly | `INSTANTLY_API_KEY` | Bearer | cursor pagination (`starting_after`); connect-your-own (BYOK, self-serve) |
| justcall | `JUSTCALL_API_KEY`, `JUSTCALL_API_SECRET` | header `Authorization: key:secret` (no scheme) | needs JustCall's Team plan or higher; BYOK-only; the customer connects it themselves on the Integrations page (API Key + API Secret) |
| leadmagic | `LEADMAGIC_API_KEY` | header `X-API-Key` | |
| lemlist | `LEMLIST_API_KEY` | HTTP Basic (`'' : key`) | paths mapped from slugs — verify; connect-your-own (BYOK, self-serve) |
| lever | `LEVER_API_KEY` | HTTP Basic (key as username) | ATS job posting; every write needs a `perform_as` user id; connect-your-own (BYOK, self-serve) |
| loxo | `LOXO_API_KEY`, `LOXO_AGENCY_SLUG` | Bearer | agency-scoped base URL derived from the slug, e.g. `acme`; connect-your-own (BYOK, self-serve) |
| lusha | `LUSHA_API_KEY` | header `api_key` | |
| openmart | `OPENMART_API_KEY` | `Authorization: Bearer` | BYOK-only, self-serve; search/enrich calls and async batch starts run on the client's Openmart account; account balance and batch status/task-ID/result reads are free |
| prospeo | `PROSPEO_API_KEY` | header `X-KEY` | enrich/search/suggestions live-confirmed |
| recruit_crm | `RECRUITCRM_API_KEY` | Bearer | 35 methods; full CRUD; connect-your-own (BYOK, self-serve) |
| recruitee | `RECRUITEE_API_KEY`, `RECRUITEE_COMPANY_ID` | `Authorization: Bearer` | ATS job posting; token is per user AND per company; company id or subdomain is a path segment; connect-your-own (BYOK, self-serve) |
| recruiterflow | `RECRUITERFLOW_API_KEY` | header `RF-Api-Key` | connect-your-own (BYOK, self-serve) |
| reply_io | `REPLY_IO_API_KEY` | `Authorization: Bearer` | scoped `domain:verb` keys (e.g. `sequences:operate`); connect-your-own (BYOK, self-serve) |
| sendkit | `SENDKIT_API_KEY` | header `X-Api-Key` | workspace key only (`sk_...`); a platform key (`sk_user_...`) is rejected; deliverability reads (mailbox health, warmup, inbox-placement/blacklist tests); connect-your-own (BYOK, self-serve) |
| serper | `SERPER_API_KEY` | header `X-API-KEY` | google.serper.dev + scrape.serper.dev |
| smartlead | `SMARTLEAD_API_KEY` | **query param** `api_key` | not a header; connect-your-own (BYOK, self-serve) |
| smartrecruiters | `SMARTRECRUITERS_API_KEY` | header `x-smarttoken` | ATS job posting; connect-your-own (BYOK, self-serve) |
| spott | `SPOTT_API_KEY` | header `x-api-key` | 61 methods; read + create/update, no record delete; connect-your-own (BYOK, self-serve) |
| theirstack | `THEIRSTACK_API_KEY` | `Authorization: Bearer` | credits: jobs + companies billed per result (check `hyreflow tools get theirstack <method>` for the live rate); blur_company_data=free preview |
| predictleads | `PREDICTLEADS_API_KEY`, `PREDICTLEADS_API_TOKEN` | headers `X-Api-Key` + `X-Api-Token` (**inferred — verify**) | funding/hiring discovery; JSON:API; base `/api/v3`; company endpoints per-request (≤1000), discover per-result; paths/auth flagged verify-on-pilot |
| shovels | `SHOVELS_API_KEY` | header `X-API-Key` | BYOK-only for user workspaces; no managed fallback for workspace calls; US building permits + contractors; cursor pagination; searches need geo_id+permit_from/to |
| github | `GITHUB_TOKEN` | `Authorization: Bearer` (PAT) | dev sourcing; REST 5k/hr, Search 30/min + 1000 cap; emails public-only → enrich downstream |
| clinicaltrials | **none** | **no auth (public API)** | pharma/biotech hiring signals; pageToken pagination; signal detection = recipe (diff snapshots) |
| layoffsignal | **none** (Hyreflow **Native**) | **no auth** (free public RSS) | layoff/RIF recruiting trigger; free (0 credits), NO BYOK key; Google News RSS + per-site feeds; links via firecrawl |
| builtwith | `BUILTWITH_API_KEY` | **`KEY` query param** | BYOK-only for user workspaces; no managed fallback for workspace calls; technographics; versioned per-API paths; Lists is heavy (OFFSET paging) |
| zoominfo | `ZOOMINFO_CLIENT_ID`, `ZOOMINFO_CLIENT_SECRET` | OAuth2 client-credentials → Bearer | token `POST /gtm/oauth/v1/token` (~1h, auto-refreshed; no `scope` sent); per-endpoint scopes (api:data:contact/company, api:insights:read…) granted on the DevPortal app; BYOK-only — self-serve Client ID + Client Secret on the Integrations card |
| sourcewhale | `SOURCEWHALE_API_KEY`, `SOURCEWHALE_USER_EMAIL` | header `api-key` (raw, confirmed) | BYOK-only, self-serve: dashboard Integrations → API key + user email (`userEmail` query param on most calls) |
| trackerrms | `TRACKERRMS_ACCESS_TOKEN`, `TRACKERRMS_JWT` (optional), `TRACKERRMS_BASE_URL` (optional) | `Authorization: Bearer <JWT>` (exchanged from the OAuth2 access token) | self-serve OAuth — Integrations → TrackerRMS (secret from Tracker support + region); env vars are the standalone path only, never read by a connected workspace |
| vincere | `VINCERE_TENANT`, `VINCERE_API_KEY`, `VINCERE_ID_TOKEN` | `x-api-key` + `id-token` | self-serve OAuth — Integrations → Vincere (tenant + Client ID + API key, all issued by Vincere Support; no secret); id_token 1 h TTL, refreshed automatically; env vars are the standalone path only, never used for a workspace |
| granola | `GRANOLA_API_KEY` | header `Authorization: Bearer` | meeting notes/transcripts/folders; connect-your-own (BYOK, self-serve, Business plan) |
| jobadder | `HYREFLOW_JOBADDER_CLIENT_ID` + `HYREFLOW_JOBADDER_CLIENT_SECRET` (Hyreflow's own registered app; the per-workspace connection carries the refresh token) | OAuth authorization-code → refresh-token grant → Bearer | self-serve OAuth (not BYOK): dashboard Integrations → Connect JobAdder → authorize; no app registration. Optionally paste your own app's Client ID + Client Secret instead. Region-specific base URL returned by the token endpoint |
| wiza | `WIZA_API_KEY` | Bearer | LinkedIn → email/phone reveal; async reveal (start → poll) |
| zoho_recruit | `HYREFLOW_ZOHO_RECRUIT_CLIENT_ID` + `HYREFLOW_ZOHO_RECRUIT_CLIENT_SECRET` (Hyreflow's own registered app; the per-workspace connection carries the refresh token) | OAuth authorization-code → refresh-token grant → `Zoho-oauthtoken` Bearer | self-serve OAuth — dashboard Integrations → Zoho Recruit → Connect; pick a data center (`us`, `eu`, `in`, `au`, `jp`, `ca`, `sa` or `cn`) — regional accounts host, but the callback's account server is authoritative. Optionally register your own Server-based Application and paste its Client ID + Client Secret instead. `ZOHO_RECRUIT_ACCESS_TOKEN`, `ZOHO_RECRUIT_API_DOMAIN` are the adapter's standalone/script path only, never read by a connected workspace. Read-only (Candidates search/dedup, Clients, Job Openings); field names vary per account, check `get_fields` |
| hyreflow_native | **none** (Hyreflow **Native**) | **no auth** | first-party tools: job scrapes (career pages, LinkedIn, Indeed, Arbeitsagentur, StepStone) pay-on-match per job; LinkedIn post feeds (`profile_posts`, `company_posts`), keyword post search (`search_posts`), post reactions (`post_reactions`) and LinkedIn profile lookup (`get_linkedin_profile`) per request; postcode radius (`postcode_radius`) free; email verification (`verify_emails`, per address submitted) |
| hyreflow_agent | **none** (managed server-side) | managed server-side | AI reasoning Native; `infer`/`research`; no BYOK |

**Parked (no env / no adapter):** `quil` (CoRecruit) — no public API.

## Keys to rotate
The Firecrawl keys and Instantly key pasted in chat during the build **must be rotated** — treat any
key that has touched a chat transcript as compromised.
