---
name: emailbison
description: "Cold-email campaigns via the EmailBison API: create campaigns, write the sequence, set the sending schedule, assign mailboxes, load and attach leads, register custom fields, and launch or pause sending. Use when the user mentions EmailBison, pushing leads into an EmailBison campaign, or building or launching an EmailBison campaign. Keys: BYOK. Connect your own EmailBison instance (its URL plus an API token)."
---

Use EmailBison for outbound email campaigns when the customer runs their sending on it. Every customer
has their own EmailBison instance, so connecting it takes two things: the instance URL they log in at
(e.g. `https://send.acme.com`) and an API token from **Settings → Developer API** in that instance.
Prefer an `api-user` token, which is scoped to one workspace.

- Only push leads that have passed enrichment and verification.
- Get campaign IDs from `emailbison_list_campaigns` before any write. Get mailbox IDs from
  `emailbison_list_sender_emails`.
- **Register custom fields before loading leads.** A lead whose `custom_variables` names a field that
  isn't registered on the instance is rejected. Register each one with `emailbison_create_custom_variable`
  first. Built-in fields need no registration: `first_name`, `last_name`, `email`, `company`, `title`.
- **Confirm with the user before `emailbison_resume_campaign`.** It is how a draft campaign is launched;
  EmailBison has no separate "start" call. Building the campaign and attaching leads never sends mail.

Only the methods below are supported. Deleting campaigns or leads, inbox replies, webhooks, tags, lead
lists, warmup and workspace admin are not part of this integration.

## Workflow: build and launch a campaign

1. **Create the campaign** with `emailbison_create_campaign`. It starts as a draft; keep the returned `id`.
2. **Adjust settings** if needed with `emailbison_update_campaign` (daily limits, plain text, tracking).
3. **Set the sending window** with `emailbison_create_schedule` (days, start/end time, timezone).
4. **Write the sequence** with `emailbison_create_sequence_steps`: one call with every step in
   `sequence_steps`. Set `thread_reply: true` on follow-ups so they thread under the first email.
5. **Assign mailboxes** with `emailbison_attach_sender_emails`.
6. **Register custom fields** the copy uses, if any (`emailbison_list_custom_variables` shows what's already
   there), with `emailbison_create_custom_variable`.
7. **Load leads** with `emailbison_create_or_update_leads` (up to 500 per call) and keep the returned lead
   `id`s.
8. **Attach the leads** to the campaign with `emailbison_attach_leads`.
9. **Stop and confirm**, then launch with `emailbison_resume_campaign`. Pause any time with
   `emailbison_pause_campaign`.

## Quick Reference

```bash
hyreflow tools execute emailbison_create_campaign --payload '{"name":"DE AI startups: founders"}'
hyreflow tools execute emailbison_create_schedule --payload '{"campaign_id":289,"monday":true,"tuesday":true,"wednesday":true,"thursday":true,"friday":true,"saturday":false,"sunday":false,"start_time":"09:00","end_time":"17:00","timezone":"Europe/Berlin"}'
hyreflow tools execute emailbison_create_sequence_steps --payload '{"campaign_id":289,"title":"Initial sequence","sequence_steps":[{"email_subject":"Quick question, {COMPANY}","email_body":"Hi {FIRST_NAME}, ...","wait_in_days":1,"order":1,"variant":false,"thread_reply":false},{"email_subject":"Re: Quick question","email_body":"Following up ...","wait_in_days":3,"order":2,"variant":false,"thread_reply":true}]}'
hyreflow tools execute emailbison_list_sender_emails --payload '{}'
hyreflow tools execute emailbison_attach_sender_emails --payload '{"campaign_id":289,"sender_email_ids":[12,13]}'
hyreflow tools execute emailbison_create_custom_variable --payload '{"name":"role"}'
hyreflow tools execute emailbison_create_or_update_leads --payload '{"leads":[{"email":"jane@acme.com","first_name":"Jane","last_name":"Lovelace","company":"Acme","custom_variables":[{"name":"role","value":"Head of Talent"}]}]}'
hyreflow tools execute emailbison_attach_leads --payload '{"campaign_id":289,"lead_ids":[123,124]}'
hyreflow tools execute emailbison_resume_campaign --payload '{"campaign_id":289}'
```

## Gotchas

- **Lists return one page of 15.** `emailbison_list_campaigns`, `emailbison_list_leads`,
  `emailbison_list_sender_emails` and `emailbison_list_custom_variables` return a page with
  `meta.last_page`; pass `page` to read the next one. Filter with `search` rather than paging through
  everything.
- **Some writes fail with a 200.** EmailBison can answer a lead write with HTTP 200 and `success: false`
  (for example, the workspace blocks the lead's domain). That comes back as an error, not a created lead.
  Read the message; resending the same lead won't fix it.
- **Personal email domains are skipped** by `emailbison_create_or_update_leads` (gmail.com and similar)
  unless EmailBison support has enabled them on the instance.
- **Upsert replaces by default.** On an existing lead, `emailbison_create_or_update_leads` overwrites every
  field, custom fields included. Pass `"existing_lead_behavior":"patch"` to change only the fields you send.
- **Sequences append.** `emailbison_create_sequence_steps` adds steps; it doesn't replace them. Check
  `emailbison_list_sequence_steps` first so a retry doesn't duplicate the sequence.
- **Leads attached to a live campaign** are picked up within about 5 minutes, not instantly.
- **Errors carry the instance's message.** A rejected call shows EmailBison's own validation text, which
  names the field at fault. Read it before retrying.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute emailbison <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get emailbison <method>` returns the live contract + cost). Only the methods listed below are callable.

- `attach_leads(campaign_id: int, lead_ids: list[int], allow_parallel_sending: bool | None = None) -> dict` — POST /api/campaigns/{campaign_id}/leads/attach-leads — enroll existing leads (ids from the lead calls) in a campaign. It does not start sending. `allow_parallel_sending` adds leads already in another campaign's sequence. CONFIRMED.
- `attach_sender_emails(campaign_id: int, sender_email_ids: list[int]) -> dict` — POST /api/campaigns/{campaign_id}/attach-sender-emails — assign mailboxes (ids from `list_sender_emails`) to send the campaign. CONFIRMED.
- `create_campaign(name: str, type: str | None = None) -> dict` — POST /api/campaigns — create a campaign in draft. `type` is `outbound` (default) or `reply_followup`. Nothing sends until `resume_campaign`. CONFIRMED.
- `create_custom_variable(name: str) -> dict` — POST /api/custom-variables — register a custom lead field. A lead's `custom_variables` entry is rejected unless its name is registered first. CONFIRMED.
- `create_lead(**lead) -> dict` — POST /api/leads — create one lead. Required: `first_name`, `email`. Optional: `last_name`, `title`, `company`, `notes`, `custom_variables` ([{name, value}], each name registered first via `create_custom_variable`). CONFIRMED.
- `create_or_update_leads(leads: list[dict], existing_lead_behavior: str | None = None) -> dict` — POST /api/leads/create-or-update/multiple — upsert up to 500 leads by email (same fields as `create_lead`). `existing_lead_behavior`: `put` (default, replaces every field of an existing lead) or `patch` (only the fields sent). Personal-domain emails (gmail.com, …) are skipped by the vendor. CONFIRMED.
- `create_schedule(campaign_id: int, **schedule) -> dict` — POST /api/campaigns/{campaign_id}/schedule — the sending window. Required: `monday`…`sunday` (booleans), `start_time` and `end_time` ("HH:MM"), `timezone` (e.g. Europe/Berlin). CONFIRMED.
- `create_sequence_steps(campaign_id: int, title: str, sequence_steps: list[dict]) -> dict` — POST /api/campaigns/v1.1/{campaign_id}/sequence-steps — the campaign's email sequence (the v1.1 path; the unversioned one is deprecated). Each step needs `email_subject`, `email_body` and `wait_in_days`; also `order`, `variant`, `thread_reply` (true on follow-ups to thread them). CONFIRMED.
- `get_campaign(campaign_id: int) -> dict` — GET /api/campaigns/{campaign_id} — one campaign with its stats and status. CONFIRMED.
- `get_me() -> dict` — GET /api/users — the token's user and its workspace (team). Free, no arguments: the BYOK probe. CONFIRMED.
- `list_campaigns(search: str | None = None, status: str | None = None, page: int | None = None) -> dict` — GET /api/campaigns — one page (15 rows) of campaigns with `meta.last_page`; pass `page` for the next. Filter by `search` (name) or `status` (draft, active, paused, completed, stopped, …). CONFIRMED.
- `list_custom_variables(page: int | None = None) -> dict` — GET /api/custom-variables — one page of the custom lead fields registered on the instance. CONFIRMED.
- `list_leads(search: str | None = None, page: int | None = None) -> dict` — GET /api/leads — one page (15 rows) of workspace leads with `meta.last_page`; pass `page` for the next, `search` to filter. CONFIRMED.
- `list_sender_emails(search: str | None = None, status: str | None = None, page: int | None = None) -> dict` — GET /api/sender-emails — one page of the workspace's connected mailboxes (id, email, status, daily_limit, warmup_enabled), with `meta.last_page`. CONFIRMED.
- `list_sequence_steps(campaign_id: int) -> dict` — GET /api/campaigns/v1.1/{campaign_id}/sequence-steps — the campaign's sequence id and steps.
- `pause_campaign(campaign_id: int) -> dict` — PATCH /api/campaigns/{campaign_id}/pause — stop sending; resume later with `resume_campaign`. CONFIRMED.
- `resume_campaign(campaign_id: int) -> dict` — PATCH /api/campaigns/{campaign_id}/resume — start sending (this is also how a draft campaign is launched; there is no separate start). Needs a schedule, a sequence, senders and leads first. CONFIRMED.
- `update_campaign(campaign_id: int, **settings) -> dict` — PATCH /api/campaigns/{campaign_id}/update — change campaign settings: `name`, `max_emails_per_day`, `max_new_leads_per_day`, `plain_text`, `open_tracking`, `can_unsubscribe`, `sequence_prioritization` (`followups` or `new_leads`) and the other optional fields in the spec. Only the fields passed change. CONFIRMED.

<!-- API-SURFACE:END -->
