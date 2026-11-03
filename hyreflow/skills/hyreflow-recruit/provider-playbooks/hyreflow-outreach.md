---
name: hyreflow-outreach
description: "Hyreflow Outreach, the email and LinkedIn sequencer built into a Hyreflow workspace (only when the workspace has Hyreflow CRM switched on): setup, senders and mailboxes, campaigns, the reply inbox and the do-not-contact list, read with hyreflow_outreach_search and changed with hyreflow_outreach_execute. Read before using either tool."
---

# hyreflow-outreach — the built-in sequencer

Hyreflow Outreach sends email and LinkedIn campaigns to people in Hyreflow CRM, from mailboxes and LinkedIn
accounts set up for the workspace. It is a different system from any sequencer the workspace connected as an
integration (lemlist, Instantly, Smartlead, …): those are reached through the provider catalog with their own
playbooks. When a workspace has both and the user's request names neither, ask which one first.

## How to call it

Two tools, each `{method, payload}`:

- `hyreflow_outreach_search`: reads. Free, change nothing.
- `hyreflow_outreach_execute`: writes. Free in credits.

Send `describe: true` next to `method` to get its description and payload schema; nothing runs. Campaign steps have
a nested shape (versions → steps → conditions), so get `campaign_create`'s schema before writing one. A method
without inputs (`status`, `setup`, `senders`) runs without a `payload`.

**Real messages go out** from `campaign_launch`, `campaign_resume`, `inbox_reply`, and `campaign_add_people` or
`campaign_leads_action` resume on a campaign that is already sending. Each takes `confirm: true` in the payload. Only send it when the user explicitly
asked for that send in this conversation; a draft, a preview or a test is never permission.

## Methods

### hyreflow_outreach_search

| Method | What it reads |
|---|---|
| `status` | Emails included and sent this month, mailboxes, and whether campaigns can send yet. |
| `setup` | What setup includes and the link where the user sets it up. Setup itself happens in the app. |
| `senders` | Who campaigns can send as: each sender's mailboxes and LinkedIn account. |
| `mailboxes` | Every sending mailbox: sender name, daily limit, warm-up and health, signature. |
| `campaigns` | Campaigns, newest first, with status and results. |
| `campaign_get` | One campaign: its steps, sending window, settings, chosen mailboxes (null = every ready one), what blocks launch, results. |
| `campaign_leads` | Everyone on a campaign: their step, next send, status. |
| `campaign_preview` | Every step rendered for real people, to check personalisation before launch. |
| `inbox_list` | Replies across campaigns, newest first, filterable by reply status or campaign. |
| `inbox_thread` | One conversation's messages. Reading leaves it unread. |
| `dnc_list` | The do-not-contact list (emails and whole domains). |

### hyreflow_outreach_execute

| Method | What it does |
|---|---|
| `campaign_create` | A DRAFT campaign (nothing sends): steps, or the 3-email starter template, or empty. |
| `campaign_update` | A campaign's name, steps, sender or audience list (draft or paused), and its settings, sending window and mailboxIds (also while sending). |
| `campaign_duplicate` | A copy of a campaign as a new draft, without its people. |
| `campaign_add_people` | CRM people onto a campaign (do-not-contact and unreachable are skipped). confirm on a sending one. |
| `campaign_set_variables` | Per-person values for the campaign's custom variables. |
| `campaign_remove_people` | People off a campaign: their remaining steps are cancelled. |
| `campaign_leads_action` | Pause, resume or remove chosen people (personIds): a paused person's steps and email follow-ups wait until resume. **Sends** on resume when the campaign is sending (`confirm: true`). |
| `campaign_send_test` | One email of a campaign to a test address, with sample values. |
| `campaign_launch` | **Sends.** Starts the campaign: enrols its audience and emails real people. confirm. |
| `campaign_pause` | Pauses a sending campaign. |
| `campaign_resume` | **Sends.** Resumes a paused campaign. confirm. |
| `campaign_archive` | Stops a campaign and moves it out of the list. confirm when it is sending. |
| `campaign_pin` | Pins a campaign to the top of the list, or unpins it. |
| `inbox_reply` | **Sends.** A reply in the same thread, from the same mailbox or LinkedIn account. confirm. |
| `inbox_set_status` | A conversation's reply status: interested, meeting booked, not interested, … |
| `inbox_mark_read` | Conversations marked read. |
| `inbox_do_not_contact` | Never contact this person again: blocks the email, flags the person, stops their sequences. |
| `mailbox_update` | Mailboxes' sender name, daily limit, sending on or off, signature (up to 500 at once). |
| `mailbox_photo` | Mailboxes' profile picture. |
| `dnc_add` | Emails or whole domains onto the do-not-contact list. |
| `dnc_remove` | Emails or domains off the do-not-contact list. |
| `linkedin_connect_link` | A secure link for the USER to open and connect their LinkedIn account. Never ask for LinkedIn passwords. |

## Recipes

**Is outreach ready?** `status`. If campaigns can't send yet, `setup` gives the link; the user finishes setup in
the app.

**A campaign for a shortlist.** Write the copy with the user → `campaign_create` (sender from `senders`, people's
own lines as custom variables) → `campaign_add_people` with the CRM person ids → `campaign_set_variables` →
`campaign_preview` and show the user → `campaign_send_test` to the user's own address → `campaign_launch` with
`confirm: true` only on the user's go.

**Fix copy before it goes out.** `campaign_pause` → `campaign_update` or `campaign_set_variables` →
`campaign_resume` with `confirm: true` on the user's go.

**Work the replies.** `inbox_list` (status `unread` or `interested`) → `inbox_thread` → draft the answer and show
it → `inbox_reply` with `confirm: true` once approved → `inbox_set_status`. Someone asking not to be contacted:
`inbox_do_not_contact`.

**Mailboxes.** `mailboxes` to read the current names, limits and signatures → `mailbox_update` (one call can set
the signature on every mailbox of a sender) or `mailbox_photo`.

**Results.** `campaigns` for the overview, `campaign_get` and `campaign_leads` for one campaign.
