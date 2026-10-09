# Recipe — Multi-ATS job posting (one role → every connected ATS)

**Use when:** the user wants a role to go out to more than one place at once — "post this everywhere",
"push it to all our ATSes", a multi-poster. Also use it for a **single** ATS if you want the id-resolution
and approval discipline; the flow degrades to one column cleanly.

This recipe is deliberately written for **whichever ATSes the workspace has connected**, not for a fixed
list. Every vendor-specific fact lives in one of three lookup tables (Step 3, Step 4, Step 7). Adding an
ATS is three rows — see [Adding an ATS to this recipe](#adding-an-ats-to-this-recipe) at the end.

> **`breezy` is coming soon and cannot be part of a fan-out.** Its vendor API is still in progress, so
> it is not connectable — it can never appear in the connected set Step 1 scopes to, and a `breezy_*`
> call is refused outright. It stays in the lookup tables below so the mapping is ready the day it
> opens; today the live ATSes are **ashby · lever · smartrecruiters · recruitee · trackerrms**.

## What "post to the job boards" actually means here

Hyreflow does not post to LinkedIn or Indeed directly — their posting APIs are partner-gated, and the
LinkedIn/Indeed/Arbeitsagentur/StepStone tools in this skill only **read** postings. Publishing here puts the role
live on the client's **own careers site**, the one their ATS hosts.

Onward syndication to the external boards is a separate thing, and **only one of the six documents it**:

- **smartrecruiters** — `publish_job` takes `aggregators: true`, "also push to free job aggregators". This
  is the one place a Hyreflow call reaches the boards by itself, so pass it deliberately.
- **ashby · lever · recruitee** — the vendor spec confirms a careers site and a public/published state,
  and says nothing about what else a published role reaches. Board syndication on these is configured by
  the client inside the ATS; the publish call does not control it.
- **breezy** — the spec documents neither a careers site nor syndication. `state: published` is what the
  API gives us; what it surfaces is undocumented.
- **trackerrms** — publishing flips the opportunity's own `advertDetails` (`publishOnline: true`). The
  spec documents the advert block but never says where a published advert surfaces, so board reach is
  whatever the client has configured inside Tracker.

So: promise the careers site, and describe board reach as "whatever the client already has wired up in
that ATS" unless it is smartrecruiters with `aggregators`. Never promise LinkedIn or Indeed — we do not
control it and, on five of the six, cannot even see it.

## Cost and access

Every ATS write costs **0 Hyreflow credits** — the call runs on the client's own ATS account (their key,
their vendor plan, their rate limits). What it does need is the ATS **connected in Integrations**: these
are workspace integrations and the free plan does not include them. An unconnected ATS answers
**`424 no_key`**, which is a configuration answer, not a bad payload — relay it, do not retry it.

## Inputs
- The role — one spec, in whatever form the user has it (a JD, a paste, a conversation).
- The set of ATSes to target — resolved in Step 1, never assumed.

---

## Step 1 — SCOPE: which ATSes are actually connected (free)

Ask the engine, never a hardcoded list — that is what makes a newly-added ATS work here with no edit.

```bash
hyreflow byok list
```

Take the ATSes that are connected, and confirm the target set with the user before doing anything else.
Name the ones you are skipping and why (not connected). If a listed ATS needs a second field — Recruitee
and Breezy each carry a company id alongside the key — a connected entry already has it; you do not
collect it here.

**Output:** the target list. Everything downstream runs once per entry in it.

---

## Step 2 — ROLE: collect the canonical spec ONCE (free)

One pass, then reuse it for every ATS. Re-asking per vendor is the failure this recipe exists to prevent.

| Canonical field | Notes |
|---|---|
| title | |
| description | HTML where the vendor takes HTML — keep the source copy, convert per vendor in Step 4 |
| requirements | kept separate: some vendors have a distinct field for it |
| location(s) | city + country at minimum, plus whether there are several |
| work model | onsite / hybrid / remote — a separate axis from location in most of them |
| employment type | full-time / part-time / contract / intern / temporary |
| department or team | the human name; ids come in Step 3 |
| salary | range + currency + period, if the client publishes it |

Anything the user has not given you and a target ATS requires is a question to ask **now**, in one batch —
not five separate interruptions later.

---

## Step 3 — IDS: resolve what cannot be guessed (free reads + the user)

**Lookup table 1 of 3.** This is the step that actually fails a multi-post. Every ATS keys its job to
internal ids, most of which Hyreflow cannot look up for you.

| ATS | Must have before `create_job` | Where it comes from |
|---|---|---|
| ashby | `teamId`, `locationId` (UUIDs). Add `defaultInterviewPlanId` **now** if the role will be opened in Step 7 | `ashby_list_departments` returns the teams. Location, interview-plan, template and brand UUIDs come from the user (visible in the Ashby admin URL) |
| lever | `perform_as` — a real Lever user UID; every write is attributed to a person | `lever_list_users`. `categories.team` / `.department` / `.location` are plain strings, not ids |
| smartrecruiters | `industry.id`, `function.id`, `experienceLevel.id` — all three required | not exposed by the adapter; from the user or the SmartRecruiters config screens. `department.id` from `smartrecruiters_list_departments` |
| recruitee | `location_ids` — **integers**, required even for a fully remote role | from the user (Recruitee's Locations screen). `department_id` from `recruitee_list_departments` |
| breezy | `department` is a **name**, not an id — it must match a real department exactly | `breezy_list_companies` confirms the company; department names from the Breezy admin |
| trackerrms | `client.id` (the Tracker Client the role belongs to) and `status.id`; optionally `contact.id` for the hiring contact | `trackerrms_search_clients` returns client ids; `trackerrms_get_metadata` returns the status / type / source / team ids — the free read for everything id-shaped |

> ⚠️ **Never invent an id.** A wrong UUID is a failed write and most of these vendors do not say which
> field was wrong. If an id is missing and the user cannot supply it, **skip that ATS and report it** —
> a partial post you can explain beats a post that silently went to the wrong team.

---

## Step 4 — MAP: one role → one payload per ATS (free)

**Lookup table 2 of 3.** The same role, six different schemas. Nothing is shared but the meaning.

| Canonical | ashby | lever | smartrecruiters | recruitee | breezy | trackerrms |
|---|---|---|---|---|---|---|
| title | `title` | `text` | `title` (≤256) | `title` | `name` | `name` |
| description | on the **posting**, not the job (Step 7) | `content.descriptionHtml` | `jobAd.sections.jobDescription.text` | `description` | `description` | `description` (public advert copy is `advertDetails.description`) |
| requirements | — | `content.lists[]` | `jobAd.sections.qualifications.text` | `requirements` (**required** when `kind` is `job`) | — | — (no separate field; public skills go in `advertDetails.skills`) |
| location | `locationId` (UUID) | `categories.location` (string) | `location` — either `{identifier}` **or** `{countryCode, city}`, never fields from both | `location_ids` (integers) | `location.country` (+ `city`, `state`) | `location`, `locationCity`, `locationState` (plain strings) |
| work model | `workplaceType` on the posting | `workplaceType` | `location.remote` / `.hybrid` | at least one of `on_site` / `hybrid` / `remote` must be **true** | `location.is_remote` | — (no dedicated field; public `advertDetails.workType`) |
| employment type | `employmentType` | `categories.commitment` | `typeOfEmployment.id` | — | `type` (`fullTime`, `partTime`, `contract`, `temporary`, `other`) | `contractType` |
| department | `teamId` | `categories.department` | `department.id` | `department_id` | `department` (name) | — (Tracker scopes a role by `client` + `owners`, not a department) |
| salary | — | `salaryRange` | `compensation` | — | `salary` | `payRate` / `chargeRate` + `currencyCode` (public range is `advertDetails.salaryFrom` / `salaryTo` / `salaryPer`) |

A dash means the vendor has no equivalent on the create call — drop the field for that ATS rather than
forcing it somewhere it does not belong.

Read the exact required set and enums from the vendor's own playbook before you build the payload:
[`ashby`](../provider-playbooks/ashby.md) · [`lever`](../provider-playbooks/lever.md) ·
[`smartrecruiters`](../provider-playbooks/smartrecruiters.md) ·
[`recruitee`](../provider-playbooks/recruitee.md) · [`breezy`](../provider-playbooks/breezy.md) ·
[`trackerrms`](../provider-playbooks/trackerrms.md), or `hyreflow tools get <tool> <create method>`
for the live schema.

---

## Step 5 — CREATE: one call per ATS, keep going on failure (0 credits)

```bash
hyreflow tools execute ashby_create_job --payload '{...}'
hyreflow tools execute lever_create_job --payload '{...}'
hyreflow tools execute smartrecruiters_create_job --payload '{...}'
hyreflow tools execute recruitee_create_job --payload '{...}'
hyreflow tools execute breezy_create_job --payload '{...}'
hyreflow tools execute trackerrms_create_opportunity --payload '{...}'
```

Run them one at a time and record `{ats, ok, id, error}` for each. **A failure on one ATS does not stop
the others** — partial success is the normal outcome of a multi-post, not an exception.

> ⚠️ **Never blind-retry a create.** None of these vendors documents an idempotency key, so retrying
> after an ambiguous timeout is how a client ends up with two identical requisitions. If a call times out
> or returns something you cannot classify, **list that ATS's jobs or ask the user** before calling again.

Capture the id each vendor returns — they are not interchangeable and Step 7 needs the right one:
ashby `results.id` · lever `data.id` · smartrecruiters `id` · recruitee `offer.id` (an integer) ·
breezy `_id` · trackerrms `id` (an integer).

---

## Step 6 — REPORT + ONE approval gate

Show what exists before anything goes public:

```
ashby            draft   4f2a…   ok
lever            draft   730e…   ok
recruitee        draft   567441  ok
smartrecruiters  —       —       failed: experienceLevel.id not recognised
breezy           —       —       skipped: not connected
```

Then ask **once**: publish these N drafts? Publishing is public and, on most of these vendors, awkward to
reverse — one confirmation for the whole set, not one per ATS, and not a silent continue.

Every ATS in this recipe creates as a **draft**; creating publishes nothing anywhere. Treat that as a
property to re-check for any ATS added later, not as a law.

---

## Step 7 — PUBLISH: the call differs per vendor (0 credits)

**Lookup table 3 of 3.**

| ATS | Publish call | Watch for |
|---|---|---|
| ashby | **two calls**: `ashby_set_job_status` with `Open`, then `ashby_create_job_posting` with `status: "Published"` | the open **fails without a default interview plan** (Step 3), and a published posting **must** carry a `description` — `{"type": "text/html", "value": "…"}` |
| lever | `lever_set_job_state` — `{"posting_id", "perform_as"}`, state defaults to `published` | `perform_as` is required again; `distributionChannels` defaults to **both** public and internal, so internal-only must be explicit |
| smartrecruiters | `smartrecruiters_publish_job` — `{"job_id", "visibility": "PUBLIC"}`, plus `aggregators: true` to also push to the free job aggregators | its own slower rate bucket; `PUBLISHED_JOB_AD_LIMIT_REACHED`, `NOT_AUTHORIZED_TO_PUBLISH_JOB` (also fires when the job needs approval), `COMPENSATION_REQUIRED` / `COMPENSATION_HIDDEN` |
| recruitee | `recruitee_set_job_state` — `{"offer_id"}`, state defaults to `published` | each state is its own endpoint; an empty body and the updated offer come back |
| breezy | `breezy_set_job_state` — `{"position_id"}`, state defaults to `published` | answers `204` with no body, so an empty result is **success**; can 400 once the plan's active-position limit is hit — a billing constraint, so relay it rather than retry |
| trackerrms | `trackerrms_publish_opportunity` — `{"opportunity_id", "advert"}` | Tracker has **no separate publish endpoint** — publishing PATCHes the opportunity's `advertDetails` block (`publishOnline: true`, `advertStatus: "A"`; `"C"` closes it). A published advert shows the **public** `advertDetails` copy, so pass `title` and `description` in `advert` or the board listing renders blank |

Same discipline as Step 5: continue past a per-ATS failure, record the outcome, never blind-retry.

---

## Step 8 — LEDGER: close the loop with ids

Final report, one row per ATS: **live / draft-only / failed / skipped**, with the id.

This is what makes a half-finished run recoverable. Without the ids, the only way to "fix" a run where
three published and two failed is to start over — which duplicates the three that worked. With them, the
fix is to publish the two stragglers.

If anything is left in draft, say so explicitly and say what the user needs to do about it.

---

## Where it sits

```
JD / role spec → [multi-ats-job-posting] → drafts in N ATSes → approval → live → boards + careers page
                                                                            ↓
                                             inbound applicants land in each ATS's own pipeline
```

Sourcing for the same role is a separate arc — see [`jd-to-shortlist.md`](jd-to-shortlist.md).

## Adding an ATS to this recipe

The steps are provider-agnostic on purpose. A new ATS is **three rows**:

1. **Step 3** — the ids it needs that cannot be guessed, and which free read (if any) returns them.
2. **Step 4** — its column in the field map.
3. **Step 7** — its publish call and what refuses it.

Plus two facts to establish first, because the steps assume both:

- **Does `create_job` default to a draft?** Everything here does. One that publishes on create breaks the
  Step 6 approval gate and needs calling out loudly.
- **What is the publish call, and is there one at all?** An ATS with no way to take a role live can still
  join Steps 1–6, but Step 7 has to say so rather than leave the user assuming it went out.

Standing candidates — all have a `create_job`, none has an established publish step yet: `bullhorn`
(`create_job_order`), `loxo`, `recruit_crm`, `recruiterflow`, `spott`.
