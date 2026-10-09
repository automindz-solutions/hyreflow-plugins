---
name: ashby
description: "Post a job to Ashby via its API — create the job record with a title, team, location, employment type, interview plan, template and brand. Use when the user mentions Ashby, posting a role to their ATS, or opening a requisition. Keys: BYOK-only — connect your own Ashby API key."
---

# Ashby — post a job

## Auth & access

- **Base URL:** `https://api.ashbyhq.com` · **Auth:** HTTP Basic, the API key as the username.
- **BYOK-only:** connect the client's own Ashby key in Integrations. There is no managed-key fallback,
  and the write costs 0 Hyreflow credits.
- The key needs Ashby's **`jobsWrite`** permission. An Ashby admin grants it per module under the API-key
  settings; without it the call comes back 403 with `missing_endpoint_permission`.
- Ashby is RPC-over-POST: every endpoint is `POST /<category>.<method>` with a JSON body, reads included.
- Hyreflow exposes three writes — `create_job`, `set_job_status` and `create_job_posting` — plus
  `list_departments()`, a free read that verifies a submitted key and returns the departments a
  `teamId` comes from.

## Create a job

`create_job(payload)` → `POST /job.create`. Three fields are required and the schema is closed: any field
that is not in the list below is rejected outright.

| Field | Required | Notes |
|---|---|---|
| `title` | yes | the job title |
| `teamId` | yes | UUID of the department/team |
| `locationId` | yes | UUID of the location |
| `defaultInterviewPlanId` | no | UUID; a job cannot be OPENED without one |
| `jobTemplateId` | no | UUID; only an **active** template may be used |
| `employmentType` | no | `FullTime`, `PartTime`, `Intern`, `Contract`, `Temporary` |
| `brandId` | no | UUID of the brand the job publishes under |

```bash
hyreflow tools execute ashby_create_job --payload '{
  "title": "Senior Platform Engineer",
  "teamId": "f9e52a51-a075-4116-a7b8-484deba69004",
  "locationId": "3ae2b801-19f6-41ef-ad28-214bd731948f",
  "employmentType": "FullTime"
}'
```

The response is `{success, results}`; the new job's id is `results.id`.

## Where the ids come from

`list_departments()` returns the `teamId` values. `locationId`, `defaultInterviewPlanId`,
`jobTemplateId` and `brandId` are Ashby UUIDs Hyreflow does not look up — ask the user for them, or have
them read the ids out of Ashby (Locations, Job Templates and Brands each show the id in the admin URL).
**Never invent a UUID** — a wrong id is a failed write, and Ashby does not say which one was wrong.

## Getting the role live — two more calls

`create_job` alone publishes nothing. Ashby keeps the job and its candidate-facing posting as separate
objects, and a new job starts in `Draft`:

1. **`set_job_status(job_id, "Open")`** → `POST /job.setStatus`. Also takes `Draft`, `Closed` and
   `Archived`; `close_reason_id` is accepted only alongside `Closed`. A job **cannot be opened until it
   has a default interview plan**, so set `defaultInterviewPlanId` at create time or the open fails.
2. **`create_job_posting(payload)`** → `POST /jobPosting.create`. This is the step that puts the role on
   a careers page. Only `jobId` is required; the posting defaults to `Draft`, so pass
   `"status": "Published"` to go live — and a published posting **must** carry a description.

| Field | Required | Notes |
|---|---|---|
| `jobId` | yes | the job the posting belongs to |
| `title` | no | defaults to the parent job's title |
| `description` | when publishing | `{"type": "text/html", "value": "<p>…</p>"}` |
| `status` | no | `Draft` (default) or `Published` |
| `workplaceType` | no | `OnSite`, `Hybrid`, `Remote` |
| `isListed` | no | defaults to true; forced false when the parent job is confidential |
| `locationId` | no | inherits the job's location |
| `secondaryLocationIds` | no | additional locations |
| `applicationFormDefinitionId` | no | falls back to the org default form |

```bash
hyreflow tools execute ashby_create_job_posting --payload '{
  "jobId": "1be42b8e-cafd-4beb-8121-f4981eb20f42",
  "description": {"type": "text/html", "value": "<p>Own the deployment platform.</p>"},
  "status": "Published",
  "workplaceType": "Hybrid"
}'
```

**`confidential` still cannot be set through the API** — not on create, not on update.

**If opening the job fails on a plus/enterprise plan**, the org most likely requires an *Opening*
associated with the job first. Ashby has a separate `opening` concept for headcount that Hyreflow does
not expose; the user creates it in Ashby, then the open succeeds. Ashby's API reference never mentions
this — only its product documentation does — so the error will not explain itself.

Publishing is public and irreversible in the way that matters: candidates can see it. Confirm with the
user before the `Published` call, not after.

## Guardrails

- This is a **write into the customer's own ATS**, so it is approval-gated: confirm the exact payload with
  the user before executing, and echo back the title, team, location and employment type you are about to
  send.
- **Retrying is not safe.** Ashby documents no idempotency key for job creation, so a retried call can
  create a second job. If a call times out, check Ashby before re-running.
- Ashby answers a REJECTED write with HTTP 200 and `success: false`. Hyreflow turns that into an error
  rather than a fake success, so treat any error text as "the job was not created".

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute ashby <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get ashby <method>` returns the live contract + cost). Base: `https://api.ashbyhq.com`. Only the methods listed below are callable.

- `create_job(payload: dict) -> Any` — POST /job.create — create a job in Draft status (opening and posting it are separate calls).
  - requires: title, teamId, locationId
  - example: `{"title":"Senior Platform Engineer","teamId":"f9e52a51-a075-4116-a7b8-484deba69004","locationId":"3ae2b801-19f6-41ef-ad28-214bd731948f","employmentType":"FullTime"}`
- `create_job_posting(payload: dict) -> Any` — POST /jobPosting.create — publish the candidate-facing posting for an existing job.
  - requires: jobId
  - example: `{"jobId":"1be42b8e-cafd-4beb-8121-f4981eb20f42","title":"Senior Platform Engineer","description":{"type":"text/html","value":"<p>Own the deployment platform.</p>"},"workplaceType":"Hybrid","status":"Published","isListed":true}`
- `list_departments() -> Any` — POST /department.list — the departments a job's `teamId` comes from, and the connection check.
- `set_job_status(job_id: str, status: str, *, close_reason_id: str | None = None) -> Any` — POST /job.setStatus — move a job between Draft, Open, Closed and Archived.

<!-- API-SURFACE:END -->

## Handoff

Shortlist → outreach lives in the sequencers. Ashby is the end of the job-side arc: once the role exists,
the candidate work (sourcing, enrichment, sequencing) is unchanged — this playbook only covers standing
the role up.
