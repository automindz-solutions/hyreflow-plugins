---
name: recruitee
description: "Post a job to Recruitee via its ATS API — create an offer with a title, description, requirements, locations, department, work model and application-form location picker. Also creates talent pools. Use when the user mentions Recruitee or Tellent, or pushing a role to their ATS. Keys: BYOK-only — connect your own Recruitee token and company."
---

# Recruitee — post a job

Recruitee calls a job an **offer**, and the same endpoint creates either a real job or a talent pool.

## Auth & access

- **Base URL:** `https://api.recruitee.com`, with the company in the path · **Auth:** Bearer token.
- **BYOK-only:** connect the client's own Recruitee token **and** their company id or subdomain in
  Integrations. There is no managed-key fallback, and the write costs 0 Hyreflow credits.
- A Recruitee token is **personal and per-company**: it carries exactly the permissions of the user who
  minted it, acts in that user's name, and a token from one company is not valid in another. Whoever
  mints it is who the offer will look like it came from.
- Hyreflow exposes one write, `create_job`, plus `list_departments()` — a free read that verifies a
  submitted token and returns the departments a `department_id` comes from.
- The public careers-site API is a different host and does not create offers.

## Create an offer

`create_job(payload)` → `POST /c/{company}/offers`. Hyreflow wraps the body in Recruitee's `offer`
envelope, so write the field names directly.

| Field | Required | Notes |
|---|---|---|
| `title` | yes | the offer title |
| `description` | yes | the offer description |
| `requirements` | yes for a job | optional when `kind` is `talent_pool` |
| `location_ids` | yes | an array of Recruitee location ids — required **even for a remote role**, because some job boards demand the detail |
| `kind` | no | `job` (default) or `talent_pool` |
| `department_id` | no | assigns the offer to an existing department |
| `on_site` / `hybrid` / `remote` | **one of them** | the work model shown on the careers site; at least one must be `true`, and none defaults to true |
| `visibility_options` | no | defaults to `["locations_question"]`, which adds a location picker to the application form |
| `locations_question` | no | the picker's question text |
| `locations_question_type` | no | `single_choice` (default) or `multiple_choice` |
| `locations_question_required` | no | force a preferred location to be picked |

```bash
hyreflow tools execute recruitee_create_job --payload '{
  "title": "Senior Platform Engineer",
  "location_ids": [12345],
  "description": "<p>Own the deployment platform.</p>",
  "requirements": "<p>Kubernetes, five years of platform work.</p>",
  "kind": "job",
  "hybrid": true
}'
```

The response is `{offer}`; the id is `offer.id`, and `offer.slug` is what appears in the careers URL.

## Where `location_ids` comes from

They are numeric Recruitee location ids, and Hyreflow does not expose the locations endpoint. Ask the
user for them, or have them read the ids out of Recruitee's Locations settings. There is **no way to pass
a location as a string** on create — the derived `location` text on the response is read-only.

## What you cannot set here

Recruitee's ATS API accepts **none** of salary, employment type, category, experience, education, hours,
pipeline template, open questions, followers, hiring managers, or `status` when creating an offer. They
exist only as read-only fields on the response. Whether a fresh offer lands as draft or published is not
part of Recruitee's documented contract either.

`status` is read-only too — but it is not stuck. Recruitee moves an offer with a per-transition endpoint
rather than a writable field, which is what `set_job_state` calls.

So: create the offer with what the API accepts, then tell the user which details still need finishing
inside Recruitee. Do not promise a salary band or pipeline that this call cannot set.

## Publishing it

A created offer is a **draft**. `set_job_state(offer_id)` → `PATCH /c/{company}/offers/{id}/publish`
takes it live on the careers site:

```bash
hyreflow tools execute recruitee_set_job_state --payload '{"offer_id": 567441}'
```

`state` also accepts `draft`, `closed` and `archived`; each maps to its own Recruitee endpoint, and all
of them send an empty body and return the updated offer.

These transitions are documented in Recruitee's full API reference rather than the OpenAPI its docs site
embeds — so an offer looks unpublishable if you only read the latter.

## Guardrails

- This is a **write into the customer's own ATS**: confirm the payload before executing.
- Recruitee documents no validation-error shape, so a rejected create can come back thin. If a create
  fails, re-check the required four (`title`, `description`, `requirements`, `location_ids`) and that one
  of `on_site` / `hybrid` / `remote` is true, rather than guessing at the message.
- `kind` is the only thing separating a job from a talent pool. Read it back before executing — creating
  a talent pool when the user asked for a job is a silent, plausible-looking mistake.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute recruitee <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get recruitee <method>` returns the live contract + cost). Base: `https://api.recruitee.com`. Only the methods listed below are callable.

- `create_job(payload: dict) -> Any` — POST /c/{company_id}/offers — create an offer as a draft (a job, or a talent pool via `kind`).
  - requires: title, location_ids, description, requirements
  - example: `{"title":"Senior Platform Engineer","location_ids":[12345],"description":"<p>Own the deployment platform.</p>","requirements":"<p>Kubernetes, five years of platform work.</p>","kind":"job","hybrid":true}`
- `list_departments() -> Any` — GET /c/{company_id}/departments — the departments an offer's `department_id` comes from, and the connection check.
- `set_job_state(offer_id: Any, state: str = 'published') -> Any` — PATCH /c/{company_id}/offers/{offer_id}/{publish|draft|close|archive} — publish an offer.

<!-- API-SURFACE:END -->

## Handoff

Once the offer exists, its careers URL is the link to put in outreach. Sourcing, enrichment and
sequencing are unchanged — this playbook only covers standing the role up.
