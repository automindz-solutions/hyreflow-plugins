---
name: breezy
description: "Post a job to Breezy HR via its v3 API — create a position with a title, description, employment type, location, department, category, experience and education levels, salary band, pipeline, questionnaire, tags and application-form field visibility. COMING SOON — not connectable yet: Breezy's own v3 API is a work in progress, so the key cannot be saved and every breezy_* call is refused. Use when the user mentions Breezy so you can say that and route them to another ATS. Keys: BYOK-only — connect your own Breezy token and company."
---

# Breezy HR — post a job

**Status: coming soon — do not attempt a call.** Breezy publishes its own v3 API as a work in progress,
so Hyreflow lists the integration without opening it: Hyreflow refuses to save a key for Breezy (saving
one returns 404), and with no managed fallback (BYOK-only) every `breezy_*` call fails. If the user asks for
Breezy, say it is coming soon because the vendor's API is still being built, and offer
[[ashby]], [[lever]], [[smartrecruiters]] or [[recruitee]] — all four post a job today and
[`recipes/multi-ats-job-posting.md`](../recipes/multi-ats-job-posting.md) fans one role across them.
Everything below is the adapter as it will ship; keep it current, but do not execute against it.

Breezy calls a job a **position**.

## Auth & access

- **Base URL:** `https://api.breezy.hr/v3`, with the company in the path · **Auth:** the `Authorization`
  header carrying the **raw** token — Breezy has no `Bearer` prefix and treats one as part of the token.
- **BYOK-only:** connect the client's own Breezy personal access token **and** their company id in
  Integrations. There is no managed-key fallback, and the write costs 0 Hyreflow credits.
- The company's Breezy plan must have the Developer API feature enabled.
- Hyreflow exposes two writes, `create_job` and `set_job_state`, plus `list_companies()` — a free read
  that verifies a submitted token and returns the companies it can reach.

## Create a position

`create_job(payload)` → `POST /company/{company}/positions`. Required: `name`, `description`, `type` and
`location.country`.

| Field | Required | Notes |
|---|---|---|
| `name` | yes | the position title |
| `description` | yes | the position details |
| `type` | yes | `fullTime`, `partTime`, `contract`, `temporary`, `other` |
| `location.country` | yes | 2-letter ISO country code |
| `location.state` | no | validated against US states / Canadian provinces when the country is `US` or `CA` |
| `location.city` | no | |
| `location.is_remote` | no | boolean |
| `requisition_id` | no | your own tracking id |
| `department` | no | must match the **name** of one of the company's departments |
| `category` | no | `software`, `design`, `product`, `sysadmin`, `devops`, `finance`, `custserv`, `sales`, `marketing`, `pr`, `hr`, `management`, `operations`, `other`, or a custom category id |
| `experience` | no | `na`, `internship`, `entry-level`, `associate`, `mid-level`, `senior-level`, `executive` |
| `education` | no | `unspecified`, `high-school`, `certification`, `vocational`, `associate-degree`, `bachelors-degree`, `masters-degree`, `doctorate`, `professional`, `some-college`, `vocational-diploma`, `vocational-degree`, `some-high-school` |
| `salary` | no | `{from, to, period, currency}` |
| `pipeline_id` / `scorecard_id` / `questionnaire_id` | no | must be ids that exist in the company, or the call 404s |
| `tags` | no | free-form strings |
| `application_form` | no | per-field visibility — see below |

`application_form` takes `required`, `optional` or `hidden` for each of `name`, `headline`, `summary`,
`profile_photo`, `address`, `salary`, `email_address`, `phone_number`, `resume`, `work_history`,
`education`, `cover_letter` and `preferred_location`, plus the boolean `questionnaire_in_experience`.

```bash
hyreflow tools execute breezy_create_job --payload '{
  "name": "Senior Platform Engineer",
  "description": "<p>Own the deployment platform.</p>",
  "type": "fullTime",
  "location": {"country": "US", "state": "CA", "city": "San Francisco", "is_remote": false},
  "experience": "senior-level",
  "education": "bachelors-degree",
  "salary": {"from": 160000, "to": 200000, "period": "yearly", "currency": "USD"},
  "tags": ["platform"]
}'
```

The response is the full position; its id is `_id`.

## The trap: Breezy drops what it does not recognise

Breezy **silently discards** any field outside its documented schema before saving — a mistyped key
produces a success with the value missing, not an error. Hyreflow rejects unknown top-level keys for
exactly this reason, so an error naming an "unsupported field" means a typo, not a missing feature.

The same asymmetry bites on round-trips: a position read back from Breezy returns `type`, `experience`
and `category` as objects, while the create call takes plain strings. Take the `.id`, never the object.

## Publishing it

`set_job_state(position_id)` → `PUT /company/{company}/position/{position_id}/state`. It defaults to
`published`, and also accepts `draft`, `archived` and `closed`:

```bash
hyreflow tools execute breezy_set_job_state --payload '{"position_id": "a3f9c1d2e4b5"}'
```

Two things to know. It answers `204` with no body, so an empty result is success. And publishing **can
fail with a 400 once the company's plan hits its active-position limit** — that is a billing constraint,
not a bad payload, so relay it rather than retrying.

`pending` shows up in the state a position can be *in*, but the vendor's endpoint will not accept it as a
value to set.

## What creating a position does NOT do

- **`state` cannot be set on the create call.** Breezy decides the new position's state; moving it is
  `set_job_state`, above.
- `salary.period` and `salary.currency` are validated against Breezy's own sets, which the vendor does
  not publish. If one is refused, ask the user what their Breezy account uses.

## Guardrails

- This is a **write into the customer's own ATS**: confirm the payload before executing.
- `pipeline_id`, `scorecard_id` and `questionnaire_id` are checked by reference: a well-formed but
  non-existent id returns 404. Only send one the user gave you.
- Breezy publishes no rate limit. Hyreflow paces conservatively; do not batch positions in parallel.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute breezy <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get breezy <method>` returns the live contract + cost). Base: `https://api.breezy.hr/v3`. Only the methods listed below are callable.

- `create_job(payload: dict) -> Any` — POST /company/{company_id}/positions — create a position for the configured company.
  - requires: name, description, type, location
  - example: `{"name":"Senior Platform Engineer","description":"<p>Own the deployment platform.</p>","type":"fullTime","location":{"country":"US","state":"CA","city":"San Francisco","is_remote":false},"experience":"senior-level","education":"bachelors-degree","salary":{"from":160000,"to":200000,"period":"yearly","currency":"USD"},"tags":["platform","kubernetes"]}`
- `list_companies() -> Any` — GET /companies — the companies this token can reach, and the connection check.
- `set_job_state(position_id: str, state: str = 'published') -> Any` — PUT /company/{company_id}/position/{position_id}/state — publish, draft, archive or close.

<!-- API-SURFACE:END -->

## Handoff

Once the position exists, publishing and candidate flow happen in Breezy. Sourcing, enrichment and
sequencing are unchanged — this playbook only covers standing the role up.
