---
name: lemlist
description: "Multichannel outreach (email + LinkedIn) via the lemlist API — list/manage campaigns, add leads to campaigns, manage contacts/lists, enrich leads, read activities, start/pause campaigns. Use when the user mentions lemlist, adding leads to a lemlist campaign, or starting/pausing outreach. Keys: BYOK — connect your own lemlist account."
---

Use Lemlist for multi-channel outbound campaigns (email + LinkedIn): campaign creation, sequence steps,
lead push, and monitoring. Only the methods below are supported — anything else 404s. There is no inbox,
unsubscribe-list, webhook or campaign-rename method on this adapter, and lead state is read-only
(a lead can be removed from a campaign, not paused or re-flagged).

- Keep activation behind enrichment/verification gates — only push contacts that have been validated.
- Resolve campaign IDs from `lemlist_list_campaigns` before any write operation.
- Insert contacts in batches of 10–25 and re-check campaign stats after writes.
- Always review in Lemlist UI before starting campaigns — use the `web_url` returned by create operations.
- **`create_campaign` returns `state: "running"`, not `draft`** — pause it before building the sequence.
  No parameter on `POST /campaigns` yields a draft — lemlist's duplicate-campaign endpoint is the only
  documented API path to one, and this adapter does not expose it — so a campaign you just created reports
  a sending state even though it has no sender and no leads. Call `pause_campaign` on the
  returned `_id` first, then add steps. Note the field name differs by method: `create_campaign` and
  `pause_campaign` return `state` (pause returns `{"_id": …, "state": "paused"}`), while `get_campaign`
  and `get_campaigns` return `status`. Read the state back with `get_campaign` and expect `status`.
- Sequence-step writes need no enablement beyond a live lemlist connection — there is no per-step-type
  permission to switch on. **While the campaign is paused or draft** it **sends nothing**, so once the user
  has confirmed the cadence, building that campaign's steps is not separately gated — including the
  **message-bearing** types (`linkedinInvite` notes, `linkedinSend` and `email` bodies). `start_campaign` is
  the gate on the *first* send. This releases sequence-step writes only, and only in that state: enrolling
  leads (`lemlist_add_to_campaign`) stays gated, and adding or editing a step on a campaign that is actually
  sending reaches the leads already enrolled — `pause_campaign` first, or gate it.

## Workflow

1. **Create or list campaigns** before adding contacts.
2. **Add sequence steps** (email, LinkedIn invite, LinkedIn DM) to define the outreach flow.
3. **Add contacts** in small batches (10–25), then check stats to verify.
4. **Review in Lemlist UI** before starting — use the `web_url` returned by create operations.
5. **Start** the campaign, then **monitor** via activities.

## Quick Reference

### Campaigns

```bash
hyreflow tools execute lemlist_list_campaigns --payload '{}'
hyreflow tools execute lemlist_create_campaign --payload '{"name":"My Campaign"}'
hyreflow tools execute lemlist_start_campaign --payload '{"campaign_id":"cam_abc123"}'
hyreflow tools execute lemlist_pause_campaign --payload '{"campaign_id":"cam_abc123"}'
hyreflow tools execute lemlist_get_campaign_stats --payload '{"campaign_id":"cam_abc123","start_date":"2026-09-01T00:00:00.000Z","end_date":"2026-09-30T23:59:59.999Z"}'
```

### Sequences

```bash
hyreflow tools execute lemlist_get_campaign_sequences --payload '{"campaign_id":"cam_abc123"}'
hyreflow tools execute lemlist_add_sequence_step --payload '{"sequence_id":"seq_abc","type":"linkedinInvite","message":"Hi!","delay":0}'
hyreflow tools execute lemlist_update_sequence_step --payload '{"sequence_id":"seq_abc","step_id":"stp_xyz","type":"linkedinSend","delay":2}'
hyreflow tools execute lemlist_delete_sequence_step --payload '{"sequence_id":"seq_abc","step_id":"stp_xyz"}'
```

### Leads

`add_lead_to_campaign` adds **one lead per call** with top-level fields — there is no `contacts:[…]` array
(that shape 400s). Provide at least one of `email` / `linkedin_url`; standard fields go in `payload`.
A lead already in the campaign comes back as a provider error with
`provider_error_code: "LEAD_ALREADY_IN_CAMPAIGN"` — nothing changed on lemlist's side. Treat it as
"already enrolled", skip that lead, and don't retry it.

```bash
# Single lead (email or LinkedIn-only). Standard fields in `payload`.
hyreflow tools execute lemlist_add_to_campaign --payload '{"campaign_id":"cam_abc","email":"ada@example.com","payload":{"firstName":"Ada","lastName":"Lovelace","companyName":"Analytical Engines"}}'

# LinkedIn-only lead WITH custom merge variables — `variables` are set per-lead after creation so
# {{personalization}} renders in the sequence (they cannot be passed as standard lead fields).
hyreflow tools execute lemlist_add_to_campaign --payload '{"campaign_id":"cam_abc","linkedin_url":"https://linkedin.com/in/ada","payload":{"firstName":"Ada"},"variables":{"personalization":"Loved your talk on compilers","personalization_short":"your compilers talk"}}'

# Set/append custom variables on an already-created lead (create-only — see Custom variables below).
hyreflow tools execute lemlist_add_lead_variables --payload '{"lead_id":"lea_abc","variables":{"personalization":"Great post on X"}}'

# Read the leads back (verify vars persisted). state/limit optional.
hyreflow tools execute lemlist_get_campaign_leads --payload '{"campaign_id":"cam_abc","state":"interested"}'
hyreflow tools execute lemlist_remove_lead_from_campaign --payload '{"campaign_id":"cam_abc","email":"ada@example.com"}'
```

#### Custom merge variables

To render `{{personalization}}` (or any non-standard field) in a sequence, set it as a **custom
variable** — lemlist rejects unknown names as standard lead fields. Either pass `variables` to
`add_lead_to_campaign` (set automatically after the lead is created) or call `add_lead_variables` directly.

- **Create-only:** you cannot re-set a name that already exists on the lead (default OR custom) — it
  errors. Set each custom variable once, when the lead is first added.
- **Default names are reserved** (set these via `payload`, not `variables`): `email`, `firstName`,
  `lastName`, `picture`, `phone`, `linkedinUrl`, `companyName`, `companyDomain`, `icebreaker`. Default
  names passed in `variables` are dropped.
- **Verify** with `lemlist_get_campaign_leads` — the returned lead objects carry their custom variables.

### Activities

```bash
hyreflow tools execute lemlist_get_activities --payload '{"campaign_id":"cam_abc","type":"emailsReplied","limit":50}'
```

## Response Shape Contract

Hyreflow wraps all provider payloads in a standard result envelope: `{ "_meta": {...}, "result": <vendor payload> }`.

- `lemlist_list_campaigns` → `result.data` is an array of `{ id, name, status }`.
- `lemlist_get_campaign_stats` → `result.data` contains `{ sent, opened, clicked, replied, bounced }`.
- `lemlist_get_campaign_sequences` → `result.data` is keyed by sequence ID, each with a `steps` array.
- `lemlist_get_campaign_leads` (also aliased `lemlist_export_campaign_leads`) → `result.data` is an array of lead objects (`_id`, `email`, `firstName`, `lastName`, `state`, plus any custom variables).
- `lemlist_add_to_campaign` → `result.data` is the created lead (`_id`, fields); when `variables` were set it also carries `_variables_set` (the custom var names persisted).
- `lemlist_add_lead_variables` → `result.data` is `{ ok: true }`.
- `lemlist_create_campaign` → `result.data` includes `web_url` for UI review.

## Key Notes

- **Step types:** `email`, `linkedinInvite`, `linkedinSend`, `linkedinVisit`, `manual`, `phone`, `api`, `whatsappMessage`, `conditional`, `sendToAnotherCampaign`
- **Delays are in days** for both `add_sequence_step` and `update_sequence_step` (0 = immediate, 2 = 2 days). Do not pass seconds or hours.
- **Deep links:** Campaign mutations return `web_url` — always review in Lemlist UI before starting campaigns.
- **Lead states for export:** `all`, `contacted`, `interested`, `notInterested`, `emailsBounced`, `paused`, `emailsSent`, `emailsOpened`, `emailsReplied`
- **Activity types:** `emailsSent`, `emailsOpened`, `emailsClicked`, `emailsReplied`, `emailsBounced`, `emailsUnsubscribed`

## Gotchas

- **Delay unit:** Always days. Passing `172800` thinking "seconds" will result in a `> 1500 days` API error.
- **Sequence writes:** Pause the campaign before adding or updating steps. `create_campaign` hands back a `running` campaign, so "newly created" is not the same as "not sending".
- **Lead deduplication:** Validation rejects duplicate emails and duplicate `linkedin_url` values within the same batch. Across batches, Lemlist can reject duplicates (for example 409 conflicts), which surface in `result.data.errors`.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute lemlist <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get lemlist <method>` returns the live contract + cost). Base: `https://api.lemlist.com/api`. Only the methods listed below are callable.

- `add_conditional_step(sequence_id: str, condition_key: str, *, delay_type: str = 'within', delay: int | None = None, index: int | None = None) -> Any` — POST /api/sequences/{sequenceId}/steps with type='conditional' — adds a branch point and RETURNS `conditions: [{sequenceId, label, key, delayType, delay}, {sequenceId, fallback:true}]` — i.e. an **accepted-branch sequenceId AND a fallback (not-met) sequenceId**. Add follow-up steps into those branch sequence ids via add_sequence_step(branch_seq_id, ...). `condition_key` e.g.
- `add_lead_to_campaign(campaign_id: str, *, email: str | None = None, linkedin_url: str | None = None, payload: dict | None = None, variables: dict | None = None, **query) -> Any` — POST /api/campaigns/{campaignId}/leads/ — add a SINGLE lead (CONFIRMED). This is a single-lead call with top-level fields — there is NO `contacts:[…]` array shape (that 400s). **`email` is OPTIONAL** — a LinkedIn-only lead works with just `linkedin_url` (verified live 2026-06-02). Provide at least one of email / linkedin_url. Standard fields go in `payload`: firstName, lastName, companyName, jobTitle, phone, companyDomain, icebreaker, timezone, contactOwner, picture.
- `add_lead_variables(lead_id: str, variables: dict) -> Any` — POST /api/leads/{leadId}/variables?<name>=<value>&… — CREATE per-lead CUSTOM merge variables so `{{name}}` renders in the sequence. Custom field names + values are passed as QUERY params, NOT a JSON body (CONFIRMED from developer.lemlist.com). ⚠️ CREATE-only: a name that collides with a lemlist default var (email, firstName, lastName, picture, phone, linkedinUrl, companyName, companyDomain, icebreaker) OR an already-set custom var ERRORS — pass only NEW custom keys. Needs the leadId (the `_id` from add_lead_to_campaign's response). `variables`: {name: value, …}. Returns `{ok: true}`.
- `add_sequence_step(sequence_id: str, type: str = 'email', *, subject: str | None = None, message: str | None = None, delay: int | None = None, index: int | None = None, **fields) -> Any` — POST /api/sequences/{sequenceId}/steps — add a step. `type` ∈ email|manual|phone|api| linkedinVisit|linkedinInvite|linkedinSend|linkedinVoiceNote|conditional|whatsappMessage|sms|… Email step: `subject` (≤400), `message` (HTML body), `delay` (days, 0–1500; default 0 first/1 after), `index` (position, -1=end). **No sender required.** Extra fields (altMessage, url, method, conditionKey, images, videos…) via **fields. CONFIRMED live.
- `create_campaign(name: str, *, timezone: str | None = None, auto_review: bool | None = None, auto_review_conditions: list[str] | None = None) -> Any` — POST /api/campaigns — create a campaign; returns `state: running`, NOT draft, so pause it before building the sequence.
- `delete_sequence_step(sequence_id: str, step_id: str) -> Any` — DELETE /api/sequences/{sequenceId}/steps/{stepId} — remove a step. CONFIRMED live 2026-06-02 (note: needs the sequenceId in the path — `/sequences/steps/{id}` returns 405).
- `enrich_lead(payload: dict) -> Any` — POST /enrich — enrich a lead (see api-reference/endpoints/enrich).
- `get_activities(**params) -> Any` — GET /activities — outreach activity events (opens, replies, etc.).
- `get_campaign(campaign_id: str) -> Any`
- `get_campaign_leads(campaign_id: str, *, state: str | None = None, limit: int | None = None, **params) -> Any` — GET /api/campaigns/{campaignId}/leads/ — read the leads currently in a campaign (synchronous; the practical counterpart to the async CSV export). Returns an array of lead objects with their fields, INCLUDING any custom merge variables set via add_lead_variables — so it's how you VERIFY variables persisted. Query: `state` (scanned|contacted|interested|notInterested|paused|…), `limit` (default 100, max 500). Sorted newest-first; no cursor paging. CONFIRMED from developer.lemlist.com.
- `get_campaign_sequences(campaign_id: str) -> Any` — GET /api/campaigns/{id}/sequences — the campaign's sequence(s) (each has `_id` = sequenceId).
- `get_campaign_stats(campaign_id: str, *, start_date: str, end_date: str, **params) -> Any` — GET /api/campaigns/{campaignId}/stats — campaign performance over a date window.
- `get_campaigns(*, version: str = 'v2', **params) -> Any` — GET /api/campaigns — list campaigns. `version=v2` is REQUIRED (defaulted here); supports offset/limit (max 100)/page, sortBy=createdAt, sortOrder, status, createdBy.
- `get_contacts(**params) -> Any`
- `get_team() -> Any` — GET /team — team info (safe read-only pilot).
- `pause_campaign(campaign_id: str) -> Any`
- `remove_lead_from_campaign(campaign_id: str, email: str) -> Any`
- `start_campaign(campaign_id: str) -> Any` — POST /campaigns/{id}/start — starts sending (outreach!). Approval-gate.
- `update_sequence_step(sequence_id: str, step_id: str, **fields) -> Any` — PATCH /api/sequences/{sequenceId}/steps/{stepId} — update a step (subject, message, delay, …).
- `upsert_contact(payload: dict) -> Any` — Create/update a contact (see api-reference/endpoints/contacts/upsert-contact).

<!-- API-SURFACE:END -->
