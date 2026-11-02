---
name: hyreflow-crm
description: "Hyreflow CRM, the recruiting CRM built into a Hyreflow workspace (only when the workspace has it switched on): jobs, candidates, client companies and contacts, pipelines, notes, tasks, lists and contractors, read with hyreflow_crm_search and changed with hyreflow_crm_execute. Read before using either tool."
---

# hyreflow-crm — the built-in recruiting CRM

Hyreflow CRM is a workspace's own CRM inside Hyreflow. It is a different system from any CRM or ATS the workspace
connected as an integration (Bullhorn, Recruit CRM, Vincere, …): those are reached through the provider catalog
with their own playbooks. When a workspace has both and the user's request names neither, ask which one before
reading or writing, then stay with it for the task.

## How to call it

Two tools, each `{method, payload}`:

- `hyreflow_crm_search`: reads. Free, change nothing.
- `hyreflow_crm_execute`: writes and the paid actions.

Send `describe: true` next to `method` to get its description and payload schema; nothing runs. Do that once per
method per chat instead of guessing field names. A method without inputs runs without a `payload`; one that needs
input and gets none answers with its schema instead.

Every write leaves a receipt in the CRM's run log. Reads don't.

## How the records fit together

- **Job** (`vacancies`): one open role, optionally for a **client company**. Holds the JD, must-haves, salary,
  status and priority.
- **Pipeline entry** (`applications`): one person on one job, at a stage (SOURCED → … → PLACED), with fit score,
  tier and reasoning once screened.
- **Person** (`people`): a candidate, or a **client contact** (hiring manager, HR, founder) at a company.
- **Company** (`companies`): a CLIENT or a PROSPECT, with industry, headcount, fee and the latest hiring signal.
- **Lists**: saved sets of candidates, contacts or companies. TEAM lists everyone sees, PRIVATE only the owner.
- **Placements**: hires. A perm placement carries the salary and fee; a contract one (an assignment) the pay and
  bill rate, and its contractor gets weekly timesheets.
- **Opportunities**: BD deals with a company, by stage (LEAD → … → WON / LOST).
- **Owner**: every record has one (`ownerId`), the recruiter who looks after it.
- Notes and tasks hang off a person, job, company or pipeline entry.

## Methods

### hyreflow_crm_search

| Method | What it reads |
|---|---|
| `search_candidates` | Our own candidate database by keywords. Always first, before any paid sourcing. |
| `list` | Records of one object (jobs, companies, people, pipeline entries, placements, BD deals), filtered by owner, type, status or stage, paged with `nextCursor`. |
| `get` | One record with its relations, e.g. a job with its pipeline. |
| `tasks` | The to-do list: open (with Overdue / Today / Tomorrow / Later) or done, mine, a colleague's or everyone's, or every task on one record whoever owns it. |
| `timeline` | A record's history, newest first, plus its open tasks: notes, done tasks and pipeline entries for a person or company; the notes for a job, pipeline entry or BD deal. |
| `lists` | The saved lists the caller can see, with counts. |
| `list_entries` | The people or companies on one list, paged with `nextCursor`. |
| `contractors` | Contractors on assignment, with rates, margin and latest timesheet. |
| `contracts_ending` | Assignments ending within N days (the extension pipeline). |
| `list_datasets` | The user's recent Hyreflow datasets (searches, enrichments, shortlists) that can be imported. |

### hyreflow_crm_execute

| Method | What it does | Cost |
|---|---|---|
| `create_candidate` | One candidate by hand (deduped by LinkedIn URL or email). | free |
| `create_company` | A client or prospect company (an existing one with that name is returned). | free |
| `create_job` | A job from a pasted or described JD, optionally for a client (created if new), with salary, fee or contract rates. | free |
| `update_job` | A job's fields: JD, must-haves, status, priority, salary, fee, contract rates, client. Only pass what changes. | free |
| `add_to_pipeline` | Existing people onto a job at SOURCED (skips anyone already on it). | free |
| `move_stage` | A pipeline entry to a new stage, with a note, a rejection reason or the next action. | free |
| `create_placement` | A hire from a pipeline entry: perm (salary, fee) or contract (pay and bill rate). | free |
| `set_placement_status` | A placement on: started, invoiced, paid, or fallen off. | free |
| `update_person` | A person's fields, incl. salary, notice, right to work, consent and do-not-contact. Only pass what changes. | free |
| `update_company` | A company's name, website, type, industry, headcount, fee, terms date, hiring signal. | free |
| `add_contact` | A client contact at a company (deduped by LinkedIn URL or email). | free |
| `add_note` | A markdown note on a person, job, company or pipeline entry. | free |
| `create_task` | A to-do, optionally linked to a person, job or company. | free |
| `task_update` | A task done or not done, or a call task's outcome. | free |
| `create_list` | A new list of candidates, contacts or companies. | free |
| `add_to_list` | People or companies onto a list. | free |
| `remove_from_list` | People or companies off a list (the records stay). | free |
| `log_timesheet` | A contractor's hours or days for one week. | free |
| `approve_timesheet` | A submitted timesheet, so it can be invoiced. | free |
| `import_dataset` | People from a Hyreflow dataset into the CRM, optionally onto a job. | free |
| `export_to_dataset` | Chosen CRM people out to a new Hyreflow dataset. | free |
| `source_candidates` | New people from external databases, imported deduped. | paid, ~0.05/person |
| `find_email` | Verified work emails for CRM people. | paid, on a hit |
| `hiring_signals` | A company's open job ads, saved as a hiring signal. | paid, 0.8/company |
| `find_hiring_managers` | Likely hiring managers at a client, added as contacts. | paid, ~0.05/person |

## Paying for something

A paid method first answers `needs_approval` with an `estimate`. Tell the user the cost, and only after they agree
repeat the call with `approvedCredits` at or above it. A large approval then answers `confirmation_required`:
confirm with the user again and repeat the identical call with `approved_credits` set to the figure they approved
(or with the `confirm_token` it returned). Never approve on the user's behalf.

## Recipes

**A JD comes in.** `create_job` (client by name) → `search_candidates` (free: who we already know) →
`add_to_pipeline` the good ones → if that's thin, `source_candidates` with the job's `vacancyId` (paid, quote first)
→ read the pipeline with `get` on the job → `move_stage` the best to the next stage with a note.

**A client brief.** `update_company` (type CLIENT, fee) → `add_contact` for the hiring manager → `hiring_signals`
(paid) for what else they are hiring → `create_task` for the follow-up call.

**Moving candidates.** `get` the job → `move_stage` per entry, putting the why in the note (and a
`rejectionReason` when rejecting) → `create_task` for the next touch.

**A hire.** `create_placement` on the pipeline entry with the salary and fee (perm) or the pay and bill rate
(contract) → `set_placement_status` as it starts, is invoiced and paid.

**What's on today.** `tasks` (open, mine) → work through Overdue and Today → `task_update` each one done. Before a
call, `timeline` on the person for what happened last.

**Hand off to outreach or enrichment.** `export_to_dataset` with the people you picked, then run the workflow or
campaign on that dataset. Bring results back with `import_dataset`.

**Lists.** `lists` to find one → `list_entries` to read it → `add_to_list` / `remove_from_list`.

**Contractors.** `contracts_ending` for who to extend → `log_timesheet` per week → `approve_timesheet` once the
client approved it.
