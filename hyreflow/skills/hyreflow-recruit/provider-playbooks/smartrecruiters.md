---
name: smartrecruiters
description: "Post a job to SmartRecruiters via its Jobs API — create a job with a title, location (details or a predefined identifier), industry, function, experience level, employment type, compensation band, a full multi-section job ad and custom job properties. Use when the user mentions SmartRecruiters or pushing a role to their ATS. Keys: BYOK-only — connect your own SmartToken."
---

# SmartRecruiters — post a job

## Auth & access

- **Base URL:** `https://api.smartrecruiters.com` · **Auth:** the `x-smarttoken` header.
- **BYOK-only:** connect the client's own SmartToken in Integrations. There is no managed-key fallback,
  and the write costs 0 Hyreflow credits. The token is minted in the customer's SmartRecruiters
  Credential Manager.
- Hyreflow exposes two writes, `create_job` and `publish_job`, plus `list_departments()` — a free read
  that verifies a submitted token and returns the configured departments.
- There is no sandbox host — a test job is a real job in the customer's account.

## Create a job

`create_job(payload)` → `POST /jobs`. Required: `title`, `location`, `industry.id`, `function.id` and
`experienceLevel.id`.

| Field | Required | Notes |
|---|---|---|
| `title` | yes | 1–256 characters |
| `location` | yes | either full details or a predefined-location `identifier` — see below |
| `industry.id` | yes | an industry id from the client's SmartRecruiters reference data |
| `function.id` | yes | a job-function id |
| `experienceLevel.id` | yes | e.g. `entry_level`, `associate`, `mid_senior_level`, `director`, `executive` |
| `typeOfEmployment.id` | no | e.g. `permanent`, `contract`, `part-time`, `intern` |
| `department.id` | no | a configured department |
| `eeoCategory.id` | no | SmartRecruiters publishes no list of valid values |
| `refNumber` | no | max 63 characters, and must be unique — a reused one is refused |
| `targetHiringDate` | no | date-time |
| `template` | no | create a job template rather than a job |
| `compensation` | no | `{min, max, currency, period}`; period is `HOURLY`, `DAILY`, `WEEKLY`, `MONTHLY` or `YEARLY` |
| `jobAd.sections` | no | `companyDescription`, `jobDescription`, `qualifications`, `additionalInformation` (each `{title, text}`, text max 24,999 chars) and `videos.urls` |
| `jobAd.language` | no | `{code, label, labelNative}`; `code` is required whenever `language` is sent |
| `properties` | no | `[{id, value: {id, label}}]` — the company's own custom job properties |

### `location` is one shape or the other

Send **either** full details — `countryCode` (2-letter ISO) and `city` are required, with optional
`region`, `regionCode`, `address`, `postalCode`, `longitude` and `latitude` — **or** a single
`identifier` naming a predefined location configured for the company. Those two sets are mutually
exclusive and Hyreflow rejects a payload carrying both.

`remote`, `hybrid` and `hybridDescription` belong to BOTH shapes and stay legal with either. A predefined location that is also remote is
`{"identifier": "berlin-hq", "remote": true}`.

```bash
hyreflow tools execute smartrecruiters_create_job --payload '{
  "title": "Senior Platform Engineer",
  "refNumber": "ENG-014",
  "location": {"countryCode": "DE", "city": "Berlin", "remote": false},
  "industry": {"id": "internet"},
  "function": {"id": "engineering"},
  "experienceLevel": {"id": "mid_senior_level"},
  "typeOfEmployment": {"id": "permanent"},
  "compensation": {"min": 90000, "max": 120000, "currency": "EUR", "period": "YEARLY"},
  "jobAd": {"sections": {"jobDescription": {"title": "About the role",
                                            "text": "Own the deployment platform."}},
            "language": {"code": "en"}}
}'
```

## The trap: unknown properties vanish silently

SmartRecruiters **ignores** a job property or property value it does not recognise rather than rejecting
it. A typo in a `properties[].id` produces a 201 with the property simply missing. Get the exact ids from
the client and read the created job back in SmartRecruiters to confirm the custom fields landed.

## Publishing it

`publish_job(job_id, payload)` → `POST /jobs/{id}/publication`, which publishes the job's default ad.
Every field is optional:

| Field | Notes |
|---|---|
| `visibility` | `PUBLIC` or `INTERNAL` |
| `aggregators` | boolean — also push to job aggregators |
| `includeInternal` | boolean — publish internally alongside the public ad |
| `delayPublicInDays` | integer — hold the public posting back this many days |

```bash
hyreflow tools execute smartrecruiters_publish_job --payload '{"job_id": "<job id>", "visibility": "PUBLIC"}'
```

It answers `204` with no body, so an empty result is success, not a miss. Four refusals are worth
recognising: `PUBLISHED_JOB_AD_LIMIT_REACHED` (the company's plan cap), `NOT_AUTHORIZED_TO_PUBLISH_JOB`
(which also fires when the job needs approval first), and `COMPENSATION_REQUIRED` / `COMPENSATION_HIDDEN`
when the company's configuration disagrees with the compensation on the job.

Publishing needs the vendor's `jobs_publications_manage` permission — a token that can create jobs cannot
necessarily publish them. It is also one of the endpoints SmartRecruiters paces at 2 requests/second
rather than 10.

## What creating a job does NOT do

- **The job is not published by the create call** — that is `publish_job`, above, and there is no `status`
  field on the create request.
- **The creator is the credential.** `creator` and the hiring process are assigned from the authenticated
  token and cannot be set here.

## Guardrails

- This is a **write into the customer's own ATS**: confirm the payload before executing.
- SmartRecruiters returns a typed error code on a rejection — `INDUSTRY_NOT_FOUND`, `FUNCTION_NOT_FOUND`,
  `EXPERIENCE_LEVEL_NOT_FOUND`, `CITY_NOT_FOUND`, `COUNTRY_CODE_NOT_RECOGNIZED`,
  `LOCATION_IDENTIFIER_NOT_FOUND`, `REF_NUMBER_ALREADY_EXISTS`, `COMPENSATION_INVALID_CURRENCY` and
  others. Read the code: it names the exact field to fix, so relay it rather than retrying blind.
- The API paces at 10 requests/second. Hyreflow already spaces calls.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute smartrecruiters <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get smartrecruiters <method>` returns the live contract + cost). Base: `https://api.smartrecruiters.com`. Only the methods listed below are callable.

- `create_job(payload: dict) -> Any` — POST /jobs — create a job (unpublished; publication is a separate call).
  - requires: title, location, industry, function, experienceLevel
  - example: `{"title":"Senior Platform Engineer","refNumber":"ENG-014","location":{"countryCode":"DE","city":"Berlin","remote":false},"industry":{"id":"internet"},"function":{"id":"engineering"},"experienceLevel":{"id":"mid_senior_level"},"typeOfEmployment":{"id":"permanent"},"compensation":{"min":90000,"max":120000,"currency":"EUR","period":"YEARLY"},"jobAd":{"sections":{"jobDescription":{"title":"About the role","text":"Own the deployment platform."}},"language":{"code":"en"}}}`
- `list_departments() -> Any` — GET /configuration/departments — the departments a job's `department.id` comes from, and the connection check.
- `publish_job(job_id: str, payload: dict | None = None) -> Any` — POST /jobs/{job_id}/publication — publish a created job's default ad to its job sites.

<!-- API-SURFACE:END -->

## Handoff

Once the job exists, publishing and candidate flow happen in SmartRecruiters. Sourcing, enrichment and
sequencing are unchanged — this playbook only covers standing the role up.
