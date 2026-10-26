---
name: reply_io
description: "Multichannel outreach via the Reply.io API — resolve/create sequences, link sending mailboxes, create or import contacts, enroll them in a sequence, start/pause sending, pull sequence stats. Use when the user mentions Reply.io, enrolling contacts in a Reply.io sequence, or starting/pausing Reply.io sending. Keys: BYOK — connect your own Reply.io account."
---

Use Reply.io for multichannel outreach activation: sequence creation, mailbox linking, contact
creation/import, enrollment, and monitoring.

- Keep activation behind enrichment/verification gates -- only enroll contacts that have been validated.
- Resolve sequence IDs from `reply_io_list_sequences` (or create one) before any write operation.
- Link at least one sending mailbox to a sequence before enrolling contacts into it.
- Enroll contacts in batches of up to 10,000 using `reply_io_add_contacts_to_sequence`.
- Keep Reply.io traffic at or below 100 requests/minute and 3,000 requests/hour per user. Reporting/stats
  endpoints are stricter.
- Check that the connected API key carries `sequences:operate` before attempting to enroll or start —
  a key with only `sequences:read` can list and inspect sequences but every write 403s.
- Keep payloads provider-native. There is no shared outbound standard contract for Reply.io.

Only the methods below are supported — anything else 404s. There is no AI-SDR, inbox, tasks, webhooks,
reporting, LinkedIn-account, blacklist, template, or schedule API on this adapter.

## Workflow

1. **Resolve or create a sequence** with `reply_io_list_sequences` / `reply_io_create_sequence` (needs a
   `name` AND at least one step — a name-only create is rejected).
2. **Link sending mailboxes** to the sequence with `reply_io_link_email_account_to_sequence`.
3. **Create or import contacts** with `reply_io_create_contact` (or resolve existing ones via
   `reply_io_list_contacts` / `reply_io_search_contacts`).
4. **Enroll contacts** with `reply_io_add_contacts_to_sequence` (behind an approval gate — mail goes out
   once the sequence is running).
5. **Start the sequence** with `reply_io_start_sequence` (approval-gated — this begins real outbound
   sending).
6. **Monitor** with `reply_io_get_sequence_stats`.

## Quick Reference

### Contacts

```bash
hyreflow tools execute reply_io list_contacts --payload '{"top":25,"skip":0}'
hyreflow tools execute reply_io get_contact --payload '{"contact_id":12345}'
hyreflow tools execute reply_io create_contact --payload '{"email":"ada@acme.com","firstName":"Ada","lastName":"Lovelace","company":"Acme Corp"}'
hyreflow tools execute reply_io update_contact --payload '{"contact_id":12345,"title":"VP Engineering"}'
hyreflow tools execute reply_io search_contacts --payload '{"top":25,"rules":[{"property":"email","condition":"contains","value":"acme.com"}]}'
```

### Contact lists

```bash
hyreflow tools execute reply_io list_contact_lists --payload '{}'
hyreflow tools execute reply_io add_contacts_to_list --payload '{"list_id":111,"contact_ids":[12345,12346]}'
```

### Sequences

```bash
hyreflow tools execute reply_io list_sequences --payload '{"status":"active"}'
hyreflow tools execute reply_io get_sequence --payload '{"sequence_id":777}'
hyreflow tools execute reply_io create_sequence --payload '{"name":"Acme Corp - Book Assessment","steps":[{"type":"email","subject":"Quick question","body":"<p>Hello Ada</p>"}]}'
hyreflow tools execute reply_io start_sequence --payload '{"sequence_id":777}'
hyreflow tools execute reply_io pause_sequence --payload '{"sequence_id":777}'
hyreflow tools execute reply_io get_sequence_stats --payload '{"sequence_id":777,"dateRangePreset":"lastMonth"}'
hyreflow tools execute reply_io list_sequence_steps --payload '{"sequence_id":777}'
```

### Sequence contacts

```bash
hyreflow tools execute reply_io list_sequence_contacts --payload '{"sequence_id":777,"top":25}'
hyreflow tools execute reply_io add_contacts_to_sequence --payload '{"sequence_id":777,"contact_ids":[12345,12346]}'
hyreflow tools execute reply_io remove_contacts_from_sequence --payload '{"sequence_id":777,"contact_ids":[12346]}'
hyreflow tools execute reply_io set_contacts_status_in_sequence --payload '{"sequence_id":777,"contact_ids":[12345],"status_in_sequence":"paused"}'
hyreflow tools execute reply_io set_contacts_replied --payload '{"sequence_id":777,"contact_ids":[12345],"is_replied":true}'
```

### Email accounts

```bash
hyreflow tools execute reply_io list_email_accounts --payload '{}'
hyreflow tools execute reply_io list_sequence_email_accounts --payload '{"sequence_id":777}'
hyreflow tools execute reply_io link_email_account_to_sequence --payload '{"sequence_id":777,"email_account_id":1}'
```

### Identity

```bash
hyreflow tools execute reply_io whoami --payload '{}'
```

## Response Shape

Hyreflow wraps all provider payloads in a standard result envelope: `{ "_meta": {...}, "result": <vendor payload> }`.

- `reply_io_list_sequences` -> `result.data` is an array of Reply.io sequence objects with stable `id`,
  `name`, and `status` fields plus the upstream metadata returned by Reply.io.
- `reply_io_get_sequence_stats` -> `result.data` contains the counters Reply.io returns for the requested
  date window (preset or explicit range).
- `reply_io_add_contacts_to_sequence` / `reply_io_remove_contacts_from_sequence` -> `result.data` reflects
  the bulk contact-link operation result.
- `reply_io_create_contact` -> `result.data` is the created contact object with its new `id`.
- `reply_io_list_contacts` / `reply_io_search_contacts` -> `result.data` is a paginated list of contact
  objects.

## Gotchas

- **Scope model:** API keys are scoped `domain:verb` (e.g. `contacts:read`, `sequences:operate`). A key
  missing `sequences:operate` can read sequences but cannot enroll or start anything — this is the #1
  confusing 403. Check scopes before assuming a write failure is a payload problem.
- **Bulk caps, not clamps:** `reply_io_add_contacts_to_sequence` / `reply_io_remove_contacts_from_sequence`
  accept up to 10,000 contact ids; `reply_io_set_contacts_status_in_sequence` /
  `reply_io_set_contacts_replied` accept up to 100. The adapter raises rather than trimming an over-cap
  batch — split the batch yourself.
- **`top` max 1000, rejected not clamped:** list endpoints take `top` (page size, default 25, max 1000)
  and `skip`. Passing `top > 1000` raises instead of being silently clamped — a clamp would make a paging
  loop skip records it never received.
- **PATCH, not PUT:** `reply_io_update_contact` is a PATCH. Omitted fields keep their current value; you
  do not need to resend the whole contact.
- **Preset XOR explicit range:** `reply_io_get_sequence_stats` takes either a `dateRangePreset`
  (`lastWeek`/`lastMonth`/`lastYear`/`allTime`) or an explicit `from`/`to`, never both in the same call.
- **Name-only sequence create is rejected:** `reply_io_create_sequence` requires both a `name` and at
  least one step.
- **Replying finishes the contact:** `reply_io_set_contacts_replied` marks a contact replied and that
  finishes them in the sequence — no further steps send to them.
- **Rate limit:** 100 requests/minute and 3,000 requests/hour per user, with stricter (undocumented)
  limits on reporting/stats endpoints. A 429 carries a `Retry-After` header.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute reply_io <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get reply_io <method>` returns the live contract + cost). Base: `https://api.reply.io`. Only the methods listed below are callable.

- `add_contacts_to_list(list_id, contact_ids: list) -> Any` — POST /v3/contact-lists/{id}/add-contacts — add contacts to a list, keeping their other memberships.
- `add_contacts_to_sequence(sequence_id, contact_ids: list, **opts) -> Any` — POST /v3/sequences/{id}/contact-links/bulk — enroll contacts in a sequence (max 10000 ids). Feeds live sending — approval-gate.
- `create_contact(**fields) -> Any` — POST /v3/contacts — create a contact (email or a LinkedIn URL is the minimum).
- `create_sequence(name: str, steps: list, **opts) -> Any` — POST /v3/sequences — create a sequence; name and at least one step are required.
- `get_contact(contact_id) -> Any` — GET /v3/contacts/{id} — one contact by id.
- `get_sequence(sequence_id) -> Any` — GET /v3/sequences/{id} — one sequence with its steps, settings and linked accounts.
- `get_sequence_stats(sequence_id, **filters) -> Any` — POST /v3/sequences/{id}/stats — engagement figures for one sequence.
- `link_email_account_to_sequence(sequence_id, email_account_id) -> Any` — POST /v3/sequences/{id}/email-account-links — add one more sending mailbox to a sequence.
- `list_contact_lists(**params) -> Any` — GET /v3/contact-lists — contact lists, paged with top/skip.
- `list_contacts(**params) -> Any` — GET /v3/contacts — browse contacts, or look one up by exact email or linkedIn.
- `list_email_accounts(**params) -> Any` — GET /v3/email-accounts — mailboxes you can send from.
- `list_sequence_contacts(sequence_id, **params) -> Any` — GET /v3/sequences/{id}/contacts — who is enrolled and where each stands.
- `list_sequence_email_accounts(sequence_id) -> Any` — GET /v3/sequences/{id}/email-accounts — mailboxes linked to a sequence.
- `list_sequence_steps(sequence_id) -> Any` — GET /v3/sequences/{id}/steps — the steps of a sequence.
- `list_sequences(**params) -> Any` — GET /v3/sequences — sequences, filterable by status/owner/folder/name.
- `pause_sequence(sequence_id) -> Any` — POST /v3/sequences/{id}/pause — pause sending for a sequence.
- `remove_contacts_from_sequence(sequence_id, contact_ids: list) -> Any` — POST /v3/sequences/{id}/contact-links/bulk-delete — take contacts out of a sequence.
- `search_contacts(**body) -> Any` — POST /v3/contacts/filter — rule-based contact search, paged with top/skip.
- `set_contacts_replied(sequence_id, contact_ids: list, is_replied: bool = True) -> Any` — POST /v3/sequences/{id}/contacts/set-replied — record replies that reached you elsewhere (max 100 ids); marking replied finishes the contact here.
- `set_contacts_status_in_sequence(sequence_id, contact_ids: list, status_in_sequence: str) -> Any` — POST /v3/sequences/{id}/contacts/set-status-in-sequence — set contacts to active, paused, finished or outOfOffice in this sequence (max 100 ids).
- `start_sequence(sequence_id) -> Any` — POST /v3/sequences/{id}/start — start or resume sending. This begins real outreach.
- `update_contact(contact_id, **fields) -> Any` — PATCH /v3/contacts/{id} — partial update; omitted fields keep their value.
- `whoami() -> Any` — GET /v3/whoami — the user an API key acts as (userId, username, teamId); the cheapest way to confirm a key works.

<!-- API-SURFACE:END -->
