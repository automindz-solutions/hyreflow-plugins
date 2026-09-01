---
name: sendkit
description: "Cold-email infrastructure via the SendKit API — create/list campaigns, add leads, start/pause/resume sending, pull analytics, manage DNC, and read mailbox health, warmup stats and deliverability tests (inbox-placement, blacklist). Use when the user mentions SendKit, pushing leads into a SendKit campaign, checking a mailbox's warmup/health before sending, or starting/pausing a SendKit campaign. Keys: BYOK — connect your own SendKit account."
---

Use SendKit for outbound email campaign management, and — the thing no other sequencer in this
skill exposes — for checking a mailbox's sending health **before** you rely on it. SendKit gives
every account a dedicated IP and its own sending environment, and it publishes that environment's
mailbox health, warmup progress, inbox-placement tests and blacklist tests through the API. That
turns "did the campaign bounce a lot?" from a postmortem into a pre-flight check: confirm a mailbox
is warmed up and placing in the inbox before loading a campaign onto it, instead of learning it from
the bounce rate afterward.

- Keep activation behind enrichment/verification gates — only push leads that have been validated.
- Resolve campaign IDs from `list_campaigns` before any write operation.
- Check `get_mailbox_health` (and warmup status via `get_warmup_config`/`list_warmup_stats`) for every
  mailbox you're about to assign to a campaign, not just once at connection time.
- Configure the sequence and assign mailboxes before `start_campaign` — the server itself refuses to
  start a campaign with no mailbox, no sequence step, or no lead.
- Add leads in batches of up to 5,000 per call.
- Auth is a **workspace key** (`sk_...`) created in the SendKit UI. A platform key (`sk_user_...`)
  is rejected — it needs a workspace header this integration does not send, so it would otherwise
  pass the initial connection check and then fail every real call.

Only the methods below are supported. Inbox/conversation reads and replies, webhooks, AI agents,
tags, enrichment settings, CRM integrations, workspace/member admin, mailbox creation or connection,
and record deletion are not exposed by this integration.

## Workflow

1. **List or create a campaign** to get a stable campaign ID. A new campaign starts in draft —
   nothing sends until you start it.
2. **Check mailbox health** with `list_mailboxes` / `get_mailbox_health` and, if a mailbox is still
   warming up, `list_warmup_stats` / `get_warmup_stats` — before assigning it to the campaign.
3. **Add leads** to the campaign in batches of up to 5,000.
4. **Start the campaign.** Requires at least one mailbox, one sequence step, and one lead already on
   the server side.
5. **Monitor** with `get_campaign_analytics` and `get_analytics_overview`.

## Quick Reference

### Campaigns

```bash
hyreflow tools execute sendkit list_campaigns --payload '{"limit": 25}'
hyreflow tools execute sendkit create_campaign --payload '{"name": "Insurance Brokerage - Book Assessment"}'
hyreflow tools execute sendkit get_campaign --payload '{"campaign_id": "campaign_123"}'
hyreflow tools execute sendkit start_campaign --payload '{"campaign_id": "campaign_123"}'
```

### Leads

```bash
hyreflow tools execute sendkit add_campaign_leads --payload '{"campaign_id":"campaign_123","leads":[{"email":"ada@acme.example.com","firstName":"Ada","companyName":"Acme"}]}'
hyreflow tools execute sendkit list_campaign_leads --payload '{"campaign_id": "campaign_123"}'
```

### Deliverability

```bash
hyreflow tools execute sendkit get_mailbox_health --payload '{"mailbox_id": "mailbox_123"}'
hyreflow tools execute sendkit list_warmup_stats --payload '{"limit": 25}'
hyreflow tools execute sendkit create_inbox_placement_test --payload '{"mailboxIds": ["mailbox_123"]}'
```

## Gotchas

- **Two key types, not interchangeable.** A workspace key (`sk_...`) is already scoped and must not
  carry a workspace header; a platform key (`sk_user_...`) needs one this integration never sends.
  Connect with a workspace key.
- **A rate-limited or 5xx write is retried automatically, so treat writes as at-least-once.** A
  429 or 5xx on any call — writes included — is re-sent up to three attempts, honouring
  `Retry-After`. That means a write whose response was lost after it already landed can apply
  twice. Most of the sending paths absorb this: SendKit skips leads already in the campaign, and
  `create_leads_bulk` defaults to skipping duplicates by email. The ones that do not are
  `create_campaign` (a repeat creates a second campaign) and the two deliverability tests (each
  run sends its own seed mail). For those, read back with `list_campaigns` /
  `list_inbox_placement_tests` / `list_blacklist_tests` before re-issuing anything yourself.
- **No published request-rate limit.** SendKit exposes rate-limit headers on every response but does
  not document the number — don't plan around an assumed cap; read the headers if you need to pace a
  bulk run.
- **`add_campaign_leads` and `campaign_leads_action` (pause/resume/remove) take mutually exclusive
  selection modes** — an explicit lead list, a filter, or "select all" (with an optional exclude list).
  Combining them is rejected rather than guessed at, because guessing wrong means pausing or removing
  the wrong leads.
- **`campaign_leads_action`'s `remove` is destructive for leads with no emails sent yet** — it hard-deletes
  those and soft-removes (marks removed) the rest. There's no separate soft-only remove.
- **Whether a filter/exclude list can also narrow an explicit lead selection is not documented** — treat
  it as unsupported and pass one or the other, not both.
- **A sparse page (`data: []` with more pages available) is possible and handled** — a short page from a
  list endpoint doesn't mean you've reached the end; keep paging until the response says there's no more.
- **Bulk caps are enforced, not silently trimmed** — creating leads in bulk and adding leads to a
  campaign by explicit list both cap at 5,000 items per call; a larger batch is rejected, not truncated.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute sendkit <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get sendkit <method>` returns the live contract + cost). Base: `https://api.sendkit.ai`. Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `add_campaign_leads(campaign_id: str, payload: dict) -> Any` — POST /v1/campaigns/{id}/leads — adds leads to a campaign, which feeds an active campaign straight into sending (approval-gate). Exactly one selection mode: `leads` (each item needs `leadId` or `email`; max 5000), `filters`, or `selectAll` (optionally with
- `add_dnc_entries(payload: dict) -> dict` — POST /v1/dnc — add do-not-contact entries. Required: `entries`. Optional `type` (email, domain), `reason` (unsubscribe_link, manual, bounce, complaint). CONFIRMED.
  - requires: entries
  - example: `{"entries":["ada@acme.example.com","acme.example.com"],"type":"email","reason":"manual"}`
- `bulk_warmup(payload: dict) -> Any` — POST /v1/warmup/bulk — starts, pauses, resumes or stops warmup across many mailboxes in one call; `start`/`resume` put warmup mail on the wire (approval-gate). Required: `operation` (start, pause, resume, stop), `mailboxes`. Optional `config`. Return shape is
  - requires: operation, mailboxes
  - example: `{"operation":"start","mailboxes":["mbx_1","mbx_2"],"config":{"targetVolume":40}}`
- `campaign_leads_action(campaign_id: str, payload: dict) -> Any` — POST /v1/campaigns/{id}/leads/action — pause, resume or remove leads in bulk; `resume` puts a paused lead back into active sending (approval-gate). Required: `action` in pause, resume, remove. Selection is `leadIds` or `selectAll`; `filters`/`excludeIds` are
- `create_blacklist_test(payload: dict) -> dict` — POST /v1/blacklist-tests — create a blacklist test. Required: `mailboxIds`. Optional `name`. CONFIRMED.
  - requires: mailboxIds
  - example: `{"mailboxIds":["mbx_1"],"name":"Acme weekly blacklist sweep"}`
- `create_campaign(payload: dict) -> dict` — POST /v1/campaigns — create a campaign. Required: `name`. Optional `sequence`, `schedule`, `settings`, and mailbox assignment via any of `mailboxes`, `mailboxIds`, `mailboxEmails`, `mailboxTags`, `mailboxProvider`. Created in DRAFT — nothing sends until
  - requires: name
  - example: `{"name":"Acme Q3 outbound","sequence":[{"type":"email","order":0,"subject":"Quick question about {{companyName}}","body":"<p>Hi {{firstName}},</p>"},{"type":"wait","order":1,"waitDays":3},{"type":"email","order":2,"subject":"Re: quick question","body":"<p>Just following up.</p>"}],"schedule":{"timezone":"America/New_York","startTime":"09:00","endTime":"17:00","workingDays":[1,2,3,4,5]},"settings":{"trackOpens":true,"stopOnReply":true},"mailboxTags":["acme-outbound"]}`
- `create_inbox_placement_test(payload: dict) -> dict` — POST /v1/inbox-placement — creates an inbox-placement test, which sends seed mail (approval-gate). Required: `mailboxIds`. Optional `name`, `mailboxTypes`, `customSubject`, `customBody`. CONFIRMED.
  - requires: mailboxIds
  - example: `{"mailboxIds":["mbx_1"],"name":"Acme pre-launch check"}`
- `create_lead(payload: dict) -> dict` — POST /v1/leads — create a lead. Required: `email`. Optional firstName, lastName, companyName, jobTitle, phone, linkedinUrl, city, state, country, tags, customFields.
  - requires: email
  - example: `{"email":"ada@acme.example.com","firstName":"Ada","lastName":"Example","companyName":"Acme","jobTitle":"VP Engineering","customFields":{"industry":"SaaS"}}`
- `create_leads_bulk(payload: dict) -> dict` — POST /v1/leads/bulk — bulk-create leads. Required: `leads` (each item needs `email`; max 5000). Optional `skipDuplicates` (server default true — false updates existing leads by email), `dataCleanup` (server default true), `tag`. Unrecognized keys on a lead item
  - requires: leads
  - example: `{"leads":[{"email":"ada@acme.example.com","firstName":"Ada","companyName":"Acme"},{"email":"grace@acme.example.com","firstName":"Grace"}],"skipDuplicates":true,"tag":"acme-q3"}`
- `get_account() -> dict` — GET /v1/account — the BYOK probe: confirms the key works and returns account info, no args. CONFIRMED.
- `get_analytics_overview() -> dict` — GET /v1/analytics/overview — no args. CONFIRMED.
- `get_blacklist_test(test_id: str) -> dict` — GET /v1/blacklist-tests/{id} — single blacklist test by id. CONFIRMED.
- `get_campaign(campaign_id: str) -> dict` — GET /v1/campaigns/{id} — single campaign by id. CONFIRMED.
- `get_campaign_analytics(campaign_id: str, date_from: str | None = None, date_to: str | None = None) -> dict` — GET /v1/campaigns/{id}/analytics — `date_from`/`date_to` (ISO 8601 or date string) map to the wire's `from`/`to`; omit either for no bound. CONFIRMED.
- `get_inbox_placement_test(test_id: str) -> dict` — GET /v1/inbox-placement/{id} — single inbox-placement test by id. CONFIRMED.
- `get_mailbox(mailbox_id: str) -> dict` — GET /v1/mailboxes/{id} — single mailbox by id. CONFIRMED.
- `get_mailbox_health(mailbox_id: str) -> dict` — GET /v1/mailboxes/{id}/health — deliverability health for one mailbox. CONFIRMED.
- `get_warmup_config(mailbox_id: str) -> dict` — GET /v1/warmup/config/{id} — current warmup configuration for a mailbox.
- `get_warmup_stats(mailbox_id: str, days: int | None = None) -> dict` — GET /v1/warmup/stats/{id} — per-mailbox warmup stats, not paginated. `days`.
- `list_blacklist_tests(limit: int | None = None, cursor: str | None = None) -> Iterator[dict]` — GET /v1/blacklist-tests — cursor. CONFIRMED.
- `list_campaign_leads(campaign_id: str, status: str | None = None, limit: int | None = None, cursor: str | None = None) -> Iterator[dict]` — GET /v1/campaigns/{id}/leads — cursor; `status` (pending, active, paused, completed, bounced, unsubscribed, replied, removed). CONFIRMED.
- `list_campaigns(status: str | None = None, search: str | None = None, limit: int | None = None, cursor: str | None = None) -> Iterator[dict]` — GET /v1/campaigns — cursor; `status` (draft, active, paused, completed, archived), `search` (case-insensitive partial name match). CONFIRMED.
- `list_dnc(entry_type: str | None = None, limit: int | None = None, cursor: str | None = None) -> Iterator[dict]` — GET /v1/dnc — cursor; `entry_type` maps to the wire's `type` (email, domain).
- `list_inbox_placement_tests(limit: int | None = None, cursor: str | None = None) -> Iterator[dict]` — GET /v1/inbox-placement — cursor. CONFIRMED.
- `list_leads(search: str | None = None, tags: list | None = None, email_verified: bool | None = None, email_status: str | None = None, email_type: str | None = None, has_company: bool | None = None, has_phone: bool | None = None, seg_protected: bool | None = None, limit: int | None = None, cursor: str | None = None) -> Iterator[dict]` — GET /v1/leads — cursor; `search`, `tags`, `emailVerified`, `emailStatus`, `emailType` (all, personal, business), `hasCompany`, `hasPhone`, `segProtected`. CONFIRMED.
- `list_mailboxes(limit: int | None = None, cursor: str | None = None, **filters) -> Iterator[dict]` — GET /v1/mailboxes — cursor; `status` (active, inactive, error, warming_up, suspended, failed, pending), `provider` (gmail, outlook, azure, custom), `sendingEnabled`, `tags`, `tagMode` (any, all), `untagged`, `search`, `warmupEnabled`, `warmupStatus` (not_started,
- `list_warmup_stats(days: int | None = None, search: str | None = None, limit: int | None = None, cursor: str | None = None) -> Iterator[dict]` — GET /v1/warmup/stats — cursor; `days`, `search`. CONFIRMED.
- `pause_campaign(campaign_id: str) -> Any` — POST /v1/campaigns/{id}/pause — pauses sending. Return shape is undocumented.
- `pause_warmup(mailbox_id: str) -> Any` — POST /v1/warmup/pause/{id} — pauses warmup for a mailbox. Return shape is undocumented. CONFIRMED.
- `resume_campaign(campaign_id: str) -> Any` — POST /v1/campaigns/{id}/resume — resumes sending (approval-gate). Return shape is undocumented. CONFIRMED.
- `resume_warmup(mailbox_id: str) -> Any` — POST /v1/warmup/resume/{id} — resumes warmup sending (approval-gate). Return shape is undocumented. CONFIRMED.
- `search_leads(filters: dict | None = None, cursor: str | None = None, limit: int | None = None) -> Iterator[dict]` — POST /v1/leads/search — a read despite the verb; `filters`, `cursor` and `limit` ride in the request BODY, not the query string. Filter keys: name, companyName, jobTitle, tags, emailVerified, country, city, createdAfter, createdBefore. CONFIRMED.
- `start_campaign(campaign_id: str) -> Any` — POST /v1/campaigns/{id}/start — starts sending (approval-gate). The server requires at least one mailbox, one sequence step and one lead; pending leads are activated. Return shape is undocumented. CONFIRMED.
- `start_warmup(mailbox_id: str, payload: dict | None = None) -> Any` — POST /v1/warmup/start/{id} — starts sending warmup mail from the mailbox (approval-gate). Optional `config` (`dailyIncrease`, `targetVolume`, `replyRates`, `promotions`, `spam`). Return shape is undocumented. CONFIRMED.
- `stop_warmup(mailbox_id: str) -> Any` — POST /v1/warmup/stop/{id} — stops warmup for a mailbox. Return shape is undocumented.
- `update_campaign(campaign_id: str, payload: dict) -> dict` — PATCH /v1/campaigns/{id} — partial update of a campaign. CONFIRMED.
- `update_warmup_config(mailbox_id: str, payload: dict) -> dict` — PATCH /v1/warmup/config/{id} — update a mailbox's warmup configuration. All optional: `startingVolume`, `dailyIncrease`, `targetVolume`, `replyRates`, `promotions`, `spam`.

<!-- API-SURFACE:END -->
