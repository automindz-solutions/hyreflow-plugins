---
name: lever
description: "Post a job to Lever via its Data API — create a posting with a title, team/department/location categories, description and requirement lists, workplace type, salary range, tags and requisition codes. Use when the user mentions Lever, publishing a posting, or pushing a role to their ATS. Keys: BYOK-only — connect your own Lever API key."
---

# Lever — post a job

Lever calls a job a **posting**.

## Auth & access

- **Base URL:** `https://api.lever.co/v1` · **Auth:** HTTP Basic, the API key as the username.
- **BYOK-only:** connect the client's own Lever key in Integrations. There is no managed-key fallback, and
  the write costs 0 Hyreflow credits.
- A Lever Super Admin mints the key under Settings → Integrations and API; access to confidential objects
  is granted when the key is created, not later.
- Hyreflow exposes two writes, `create_job` and `set_job_state`, plus `list_users()` — a free read that
  verifies a submitted key and returns the users a `perform_as` comes from.
- The public `jobs.lever.co` feed is a different, read-only API. It is not what creates a posting.

## Every write needs a `perform_as` user

Lever has no system actor, so every posting is attributed to a real Lever user. Pass that user's id as
`perform_as` in the payload; Hyreflow sends it as the query parameter Lever requires, not as a body
field. That user becomes the creator and, unless `owner` says otherwise, the owner.

Ask the user whose Lever account the posting should be created under and get that user's id. Do not guess.

## Create a posting

`create_job(payload)` → `POST /postings?perform_as=…`.

Required: `perform_as` and `text`, plus `categories.team`, `categories.department` and
`categories.location`.

| Field | Required | Notes |
|---|---|---|
| `perform_as` | yes | the Lever user the posting is created as — sent as a query parameter, not in the body |
| `text` | yes | the posting title |
| `categories.team` | yes | e.g. Engineering |
| `categories.department` | yes | the department the team sits in |
| `categories.location` | yes | the job's location |
| `categories.commitment` | no | Full-time, Part-time, Internship, … |
| `categories.allLocations` | no | additional locations |
| `state` | no | `published`, `internal`, `closed`, `draft`, `pending`, `rejected` — **defaults to `draft`** |
| `distributionChannels` | no | `internal`, `public` — **defaults to BOTH** |
| `owner` / `hiringManager` | no | Lever user ids |
| `tags` | no | extra posting tags |
| `content.descriptionHtml` | no | the top-of-page description, as HTML |
| `content.lists` | no | `[{text, content}]` — requirement/responsibility lists, content as HTML |
| `content.closingPostingHtml` | no | a custom closing statement, as HTML |
| `salaryDescriptionHtml` | no | free-text salary blurb |
| `salaryRange` | no | `{currency, interval, min, max}` |
| `workplaceType` | no | `onsite`, `remote`, `hybrid` |
| `requisitionCodes` | no | requisition codes to attach |

```bash
hyreflow tools execute lever_create_job --payload '{
  "text": "Senior Platform Engineer",
  "state": "draft",
  "categories": {"team": "Engineering", "department": "Technology",
                 "location": "Berlin", "commitment": "Full-time"},
  "content": {"descriptionHtml": "<p>Own the deployment platform.</p>",
              "lists": [{"text": "Requirements", "content": "<ul><li>Kubernetes</li></ul>"}]},
  "workplaceType": "hybrid",
  "perform_as": "8d49b010-cc6a-4f40-ace5-e86061c677ed"
}'
```

The response is `{data}`; the posting's id is `data.id`, and `data.urls` carries the live list/show/apply
links once it is published.

## Publishing it

`set_job_state(posting_id, perform_as=…)` → `POST /postings/{id}?perform_as=…`, a partial update that
changes only what it sends. `state` defaults to `published`, which takes a draft posting live on the job
sites named by its `distributionChannels`:

```bash
hyreflow tools execute lever_set_job_state --payload '{
  "posting_id": "730e37db-93d3-4acf-b9de-7cfc397cef1d",
  "perform_as": "8d49b010-cc6a-4f40-ace5-e86061c677ed"
}'
```

The same call moves a posting to any other documented state — `internal`, `closed`, `draft`, `pending`,
`rejected` — and takes an optional `payload` of the create fields to change alongside it.

**`state: "internal"` is not the internal job site.** It is Lever's "unlisted": the posting appears on
NEITHER the public nor the internal job site and is reachable only by direct link. To put a posting on
the internal site only, publish it and set `distributionChannels: ["internal"]` — the identically-named
value in a different field. Lever's docs
ask you to read the posting first so a partial update doesn't clobber a concurrent edit in Lever Hire.
Updating through the API skips the approvals chain, exactly like creating does.

## `create_job`'s two defaults that surprise people

These are the defaults on **`create_job`**, and they run the opposite way to `set_job_state`'s: creating
leaves a posting dark, publishing is what takes it live.

- **On `create_job`, `state` defaults to `draft`.** A new posting is not live unless you send
  `"state": "published"` — or publish it afterwards with `set_job_state`, whose own `state` defaults to
  `published` precisely because publishing is the only thing that call is for.
- **`distributionChannels` defaults to BOTH `public` and `internal`.** An internal-only posting has to say
  `["internal"]` explicitly.

Also worth saying out loud: **creating through the API skips Lever's approvals chain.** If the client runs
approvals, create the posting as a `draft` and let them route it inside Lever Hire. A confidential posting
cannot be created through the API at all.

## Guardrails

- This is a **write into the customer's own ATS**, and publishing makes it public. Confirm the payload —
  especially `state` and `distributionChannels` — before executing.
- Lever paces at 10 requests/second per key. Hyreflow already spaces calls; do not parallelise a batch of
  postings on top of that.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute lever <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get lever <method>` returns the live contract + cost). Base: `https://api.lever.co/v1`. Only the methods listed below are callable.

- `create_job(payload: dict) -> Any` — POST /postings — create a job posting (draft unless `state` says otherwise).
  - requires: text, perform_as, categories
  - example: `{"text":"Senior Platform Engineer","state":"draft","categories":{"team":"Engineering","department":"Technology","location":"Berlin","commitment":"Full-time"},"content":{"descriptionHtml":"<p>Own the deployment platform.</p>","lists":[{"text":"Requirements","content":"<ul><li>Kubernetes</li></ul>"}]},"workplaceType":"hybrid","perform_as":"8d49b010-cc6a-4f40-ace5-e86061c677ed"}`
- `list_users() -> Any` — GET /users — the users a posting's `perform_as` comes from, and the connection check.
- `set_job_state(posting_id: str, *, perform_as: str, state: str = 'published', payload: dict | None = None) -> Any` — POST /postings/{id} — publish a posting (or move it to another state), as `perform_as`.

<!-- API-SURFACE:END -->

## Handoff

Once the posting is live, `data.urls.apply` is the link to put in outreach. Candidate sourcing and
sequencing are unchanged — this playbook only covers standing the role up.
