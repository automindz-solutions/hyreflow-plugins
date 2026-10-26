---
name: openmart
description: "Local-business data via the Openmart API — search stores or deduplicated brands, enrich a company, find owners and decision-makers, enrich known people, discover shared business inboxes, and detect technologies. Use for SMB and local-market workflows. Keys: BYOK-only."
---

# Openmart — local-business search and enrichment

## Auth & access

- **Base URL:** `https://api.openmart.ai` · **Auth:** Bearer token.
- **BYOK-only:** connect the client's own Openmart key in Integrations. There is no managed-key fallback. Connecting a key needs the Essential plan or above: on Free/Starter the connect is refused with a plan-required error, so tell the user to upgrade rather than retrying.
- `credit_balance()` is the free connection check and shows the remaining credits on that Openmart account.
- Openmart calls run on the client's vendor account. Check the exact method contract before launching a
  broad search or enrichment batch.

## Choose the right business search

- `search_businesses(payload)` searches store-level local-business records. Use it for a precise local
  market list where each physical location matters. Search accepts a business query, location and
  business-attribute filters; paginate with the last row's `cursor`.
- `search_brands(payload)` returns one row per brand rather than one row per physical store. Use it for
  account lists, market sizing, or outreach where a multi-location business should appear once. It can
  filter by location, ownership type, store count, staff/contact availability, domain and social links.
- `search_business_ids(payload)` takes the same search shape as `search_businesses` but returns only IDs,
  place IDs, match scores and cursors. Use it for a lightweight first pass when full business records are
  not needed yet.
- `enrich_company(payload)` resolves a website or social-media URL to matching business records. Supply
  at least one of `website` or `social_media_link`; location can disambiguate similar businesses.

## Country coverage

Openmart lists **16 markets**: United States, Canada, Australia, New Zealand, Puerto Rico, United
Kingdom, Ireland, France, Spain, Germany, Austria, Belgium, Netherlands, Denmark, Luxembourg and Sweden.
Expect little or no data elsewhere: a search in India returned nothing in testing, with no error. Check
the country before you start, and use a different sourcing route for markets outside this list.

## Field names that differ between endpoints

Copy these exactly. In testing, business search ignored a misspelled location field (`zipcode`) without
an error and searched the whole state instead, so a typo can look like a successful search with too many
results.

| Field | `search_businesses` / `search_business_ids` | `enrich_company` | `search_brands` |
|---|---|---|---|
| Postal code | `zip_code` (string or array) | `zip_code` (array) | `zipcode` (array, no underscore) |
| Country | `country`, defaults to US | `country`, defaults to US | `country`, required on every location entry |
| Radius | `lat` + `long` + `geo_radius` (meters) | `lat` + `long` + `geo_radius` (meters) | `geo_radius: {lat, lon, radius}` (meters) |
| Ownership | `ownership_type` string, no published value list | — | `ownership_type` array of `INDEPENDENT`, `FAMILY`, `FRANCHISE`, `CHAIN` |

A search result returns the postal code as `content.zipcode`, even though the search filter is
`zip_code`.

```json
{"query": "coffee shop", "location": [{"country": "US", "state": "TX", "city": "Austin", "zip_code": ["78701"]}], "limit": 3}
```

Run a new filter with `limit` 1–3 first and check the rows match the area you asked for, then widen it.

## Values that must be uppercase

- `info_access` on `find_people` and `lookup_people`: `["EMAIL"]`, `["PHONE"]` or both (the default).
  Lowercase `email` is rejected.
- `ownership_type` on `search_brands`: `INDEPENDENT`, `FAMILY`, `FRANCHISE`, `CHAIN`.
- The `status` filter on `get_batch_task_ids`: `COMPLETED`.

## Company → owner or decision-maker workflow

1. Search stores or brands and keep rows with a non-empty root domain.
2. Normalize and deduplicate domains. Preserve each business ID in `tracking_id` so results can be joined
   back to the correct source row.
3. Launch `find_people(tasks)` with 1–100 company task objects. Each task needs a bare root `domain`
   (no `https://`), the desired `title`, and `max_k` from 1–8; `company_name`, location hints and
   `info_access` improve control. `hyreflow tools get openmart find_people` lists every task field.
   A launch call can take 30 seconds or more before it returns the `batch_id`.
4. Poll `get_batch_status(batch_id)` until `batch_ready` is true. Do not resubmit the same batch while it
   is still processing.
5. Call `get_batch_task_ids(batch_id, status="COMPLETED")`, then call `get_task_result(task_id)` for each
   task ID. Join the results through `tracking_id`.

The same async lifecycle applies to:

- `find_tech(tasks)` — detect a specified `tech_type` (for example `shopify`, `hubspot` or `klaviyo`)
  for known company domains. Openmart publishes no full list of technologies.
- `lookup_business_email(tasks)` — find shared company inboxes such as `info@`, `support@` or `sales@`.
  Each task needs `domain` and a non-empty `company_name`.
- `lookup_people(tasks)` — enrich known people at a domain. Each task takes `domain` and `people`, a list
  of 1–8 `{first_name, last_name}` objects with an optional `linkedin_url`. In testing, a name Openmart
  could not match still completed, with `data: null`.

The launch call returns a `batch_id`; the status, task-ID and task-result reads are separate calls. A
batch can contain tasks with different final outcomes, so fetch completed task IDs and inspect each task
result rather than treating `batch_ready` as proof that every task found data.

## Email channel guardrail

Openmart is a **BD/work-email source**:

- `lookup_business_email` returns shared business mailboxes, not a person's address.
- `find_people` and `lookup_people` may return person-specific contact details at the current company,
  which are still work contacts.

Use these addresses when selling or recruiting into a company. For candidate acquisition, use the
`personal_email` waterfall and LinkedIn instead; never substitute an Openmart work address for a personal
candidate email.

## Handoff

Openmart is the company-first local-market lane: search businesses or brands → qualify against the ICP →
find the owner or relevant decision-maker → retrieve BD contact details → verify → sequence or push to the
client's CRM. Technology detection can qualify the account before contact enrichment.

In **Germany, Austria, Switzerland** (or any other market where naming the business owner in a legal
notice is mandatory), the owner's name usually comes off the site's own Impressum rather than from
`find_people`/`lookup_people` alone — follow
[`../recipes/local-business-hiring-managers.md`](../recipes/local-business-hiring-managers.md) for the
full play (Impressum extract → generic-inbox rule → name+domain work email → LinkedIn resolution →
re-enrich → validate). **`lookup_business_email` returns a shared company inbox** (`info@`, `support@`,
`sales@`, …), not a named person's address — never write that value into a person's email field.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute openmart <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get openmart <method>` returns the live contract + cost). Base: `https://api.openmart.ai`. Only the methods listed below are callable.

- `credit_balance() -> Any` — GET /api/v2/credit-balance — read the authenticated team's remaining credits.
- `enrich_company(payload: dict) -> Any` — POST /api/v1/enrich_company — match business records from a website or social URL.
  - example: `{"website":"https://acme.example.com","location":[{"country":"US","state":"CA"}],"limit":2}`
- `find_people(tasks: list[dict]) -> Any` — POST /api/v1/task/batch/find_people — start 1–100 decision-maker tasks.
- `find_tech(tasks: list[dict]) -> Any` — POST /api/v1/task/batch/find_tech — start technology-detection tasks.
- `get_batch_status(batch_id: str) -> Any` — GET /api/v1/task/batch/{batch_id}/status — poll a submitted batch.
- `get_batch_task_ids(batch_id: str, *, status: str | None = None) -> Any` — GET /api/v1/task/batch/{batch_id}/task_ids — list task IDs, optionally by status.
- `get_task_result(task_id: str) -> Any` — GET /api/v1/task/{task_id} — retrieve one completed background-task result.
- `lookup_business_email(tasks: list[dict]) -> Any` — POST /api/v1/task/batch/lookup_business_email — start 1–100 mailbox lookups.
- `lookup_people(tasks: list[dict]) -> Any` — POST /api/v1/task/batch/lookup_people — enrich 1–100 known-person tasks.
- `search_brands(payload: dict) -> Any` — POST /api/v2/brands/search — deduplicated brand/company search.
  - example: `{"search_param":{"search_term":"coffee","location":[{"country":"US","state":"TX","zipcode":["78701"]}],"ownership_type":["INDEPENDENT"]},"pagination":{"limit":20}}`
- `search_business_ids(payload: dict) -> Any` — POST /api/v1/search/only_ids — lightweight search using the full-search request body.
  - example: `{"query":"coffee shop","location":[{"country":"US","state":"TX","city":"Austin","zip_code":["78701"]}],"has_valid_website":true,"limit":25}`
- `search_businesses(payload: dict) -> Any` — POST /api/v1/search — full local-business search (limit 1–1000).
  - example: `{"query":"coffee shop","location":[{"country":"US","state":"TX","city":"Austin","zip_code":["78701"]}],"has_valid_website":true,"limit":25}`

<!-- API-SURFACE:END -->
