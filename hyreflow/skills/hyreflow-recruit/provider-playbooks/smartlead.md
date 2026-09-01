---
name: smartlead
description: "Cold-email outreach via the Smartlead API — create/list campaigns, add leads, build sequences, attach sending email accounts, pull analytics, start/pause campaigns. Use when the user mentions Smartlead, pushing leads into a Smartlead campaign, or starting/pausing email sending. Keys: BYOK — connect your own Smartlead account."
---

Use Smartlead for outbound email campaign management: campaign creation, lead push, sequencing, and monitoring.

- Keep activation behind enrichment/verification gates -- only push contacts that have been validated.
- Resolve campaign IDs from `smartlead_list_campaigns` before any write operation.
- Push leads in batches of up to 400 and re-check campaign analytics after writes.
- Keep Smartlead traffic at or below 60 requests per 60 seconds per API key. Large pools need queueing or smaller concurrency.
- Configure sequences before starting a campaign.
- Include `SMARTLEAD_API_KEY` as fallback env credential when not using org-linked auth.
- Keep payloads provider-native. There is no shared outbound standard contract for Smartlead.

Only the methods below are supported — anything else 404s. There is no schedule/settings API, no webhooks,
block-list, smart-delivery, smart-senders, or generic passthrough on this adapter.

## Workflow

1. **Create or list campaigns** to get a stable campaign ID.
2. **Add email accounts** to the campaign using `smartlead_add_campaign_email_account`.
3. **Configure sequences** with `smartlead_save_campaign_sequences` (email steps, delays, variants).
4. **Push leads** in batches (max 400) using `smartlead_push_to_campaign`.
5. **Start the campaign** with `smartlead_update_campaign_status` (status: `START`).
6. **Monitor** via `smartlead_get_campaign_analytics`.

## Quick Reference

### Campaigns

```bash
hyreflow tools execute smartlead smartlead_list_campaigns --payload '{}'
hyreflow tools execute smartlead smartlead_create_campaign --payload '{"name":"Insurance Brokerage - Book Assessment"}'
hyreflow tools execute smartlead smartlead_get_campaign --payload '{"campaign_id":"12345678"}'
hyreflow tools execute smartlead smartlead_update_campaign_status --payload '{"campaign_id":"12345678","status":"START"}'
```

### Leads

```bash
hyreflow tools execute smartlead smartlead_push_to_campaign --payload '{"campaign_id":"12345678","lead_list":[{"email":"jane@example.com","first_name":"Jane","last_name":"Lovelace","company_name":"Acme Corp","custom_fields":{"tag":"demo"}}]}'
hyreflow tools execute smartlead smartlead_list_campaign_leads --payload '{"campaign_id":"12345678"}'
```

### Sequences

```bash
hyreflow tools execute smartlead smartlead_save_campaign_sequences --payload '{"campaign_id":"12345678","sequences":[{"seq_number":1,"seq_delay_details":{"delay_in_days":0},"seq_variants":[{"email_body":"<p>Hello Ada</p>","variant_label":"A","subject":"Quick question"}]},{"seq_number":2,"seq_delay_details":{"delay_in_days":3},"seq_variants":[{"email_body":"<p>Following up</p>","variant_label":"A","subject":"Re: Quick question"}]}]}'
```

### Analytics

```bash
hyreflow tools execute smartlead smartlead_get_campaign_analytics --payload '{"campaign_id":"12345678"}'
```

### Email Accounts

```bash
hyreflow tools execute smartlead smartlead_list_email_accounts --payload '{}'
hyreflow tools execute smartlead smartlead_add_campaign_email_account --payload '{"campaign_id":"12345678","email_account_ids":[1,2,3]}'
```

## Response Shape Contract

Hyreflow wraps all provider payloads in a standard result envelope: `{ data, meta }`.

- `smartlead_list_campaigns` -> `result.data` is an array of Smartlead campaign objects with stable `id`, `name`, and `status` fields plus the upstream metadata returned by Smartlead.
- `smartlead_get_campaign_analytics` -> `result.data` contains sent/opened/clicked/replied/bounced counters, mapped from Smartlead's analytics endpoint.
- `smartlead_push_to_campaign` -> `result.data` contains `{ pushed, failed, results }`.
- `smartlead_create_campaign` -> `result.data` includes `{ ok, id, name, created_at }`.
- `smartlead_list_campaign_leads` -> `result.data` is a paginated list of lead objects.

## Gotchas

- **Campaign status values:** Only `PAUSED`, `STOPPED`, and `START` are valid. Note it is `START`, not `STARTED` or `RUNNING`.
- **Sequence ordering:** `seq_number` values must be contiguous starting at 1 (no gaps). The first sequence step (seq_number 1) must have a subject line (either at step level or on every variant).
- **Delay units:** `delay_in_days` is in days (0 = immediate). Do not pass hours or minutes.
- **Lead batch limits:** Maximum 400 leads per `push_to_campaign` call. Use `lead_list` as the canonical field. Duplicate emails within a batch are rejected. Emails are automatically lowercased for deduplication.
- **Provider rate limit:** Smartlead currently documents 60 requests per 60 seconds per API key. Avoid high parallelism on campaign mutations unless you add queueing or backoff.
- **Campaign IDs:** Accepted as integer or numeric string. Non-numeric strings are rejected.
- **API key auth:** Pass `SMARTLEAD_API_KEY` environment variable. The API key is appended as a query parameter by the integration layer.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute smartlead <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get smartlead <method>` returns the live contract + cost). Base: `https://server.smartlead.ai/api/v1`. Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `add_email_account_to_campaign(campaign_id: str, email_account_ids: list[int]) -> Any`
- `add_leads_to_campaign(campaign_id: str, lead_list: list[dict], **settings) -> Any` — POST /campaigns/{id}/leads — add leads. Feeds an active campaign into sending — approval-gate.
- `create_campaign(name: str, **opts) -> Any` — POST /campaigns/create — create a campaign.
- `get_campaign(campaign_id: str) -> Any`
- `get_campaign_analytics(campaign_id: str) -> Any`
- `list_campaigns() -> Any` — GET /campaigns — all campaigns.
- `list_email_accounts(**params) -> Any` — GET /email-accounts/ — sending mailboxes.
- `list_leads_by_campaign(campaign_id: str, **params) -> Any`
- `save_campaign_sequence(campaign_id: str, sequences: list[dict]) -> Any` — POST /campaigns/{id}/sequences — define the email steps/A-B variants.
- `update_campaign_status(campaign_id: str, status: str) -> Any` — POST /campaigns/{id}/status — status: PAUSED | STOPPED | START. START begins sending (outreach!).

<!-- API-SURFACE:END -->
