---
name: jobadder
description: "Read/write JobAdder (recruiting ATS/CRM) via its v2 API — find/get/create/update candidates, jobs, companies, contacts, applications, placements, job ads, requisitions; notes, statuses, identity search. Use when the user mentions JobAdder, pushing candidates into the ATS, attaching candidates to jobs, or reading jobs/companies/placements. Keys: OAuth app credentials, not a self-serve dashboard BYOK key."
---

# JobAdder — Integration Meta Skill

HOW in `lib/jobadder.py`. Built from the official OpenAPI v2 (spec-verified; not yet live-confirmed — needs a client OAuth app + refresh token for a read-only pilot).

## Auth & config (OAuth2, region-aware base)
- **Auth:** OAuth2 **authorization-code** flow; this client runs the **refresh-token** grant to mint ~60-min access tokens (Bearer).
- **Env:** `JOBADDER_CLIENT_ID`, `JOBADDER_CLIENT_SECRET`, `JOBADDER_REFRESH_TOKEN`. Optional pre-minted-token shortcut: `JOBADDER_ACCESS_TOKEN` (+ `JOBADDER_API_BASE`). Never hardcode. Because this is an OAuth credential rather than a single key, JobAdder is **not a self-serve integration yet** — it can't be pasted into the dashboard and isn't held per-workspace; enabling it is a conversation with Hyreflow.
- **⚠️ Base URL is returned by the token endpoint** (`api` field), region-specific (AU/EU/US shards differ — default `https://api.jobadder.com/v2`). The client reads it from the refresh response automatically — don't hardcode a region.
- **Refresh-token rotation:** JobAdder may return a new `refresh_token` on each refresh — the client keeps the latest in memory for the session; persist it back to `JOBADDER_REFRESH_TOKEN` if you run long-lived.
- **One-time setup:** authorize at `id.jobadder.com/connect/authorize` with **`offline_access`** (required for a refresh token) + the read/write scopes you need → exchange `code` at `id.jobadder.com/connect/token` → store the `refresh_token`. Scopes are granular (`read_candidate`, `write_candidate`, `read_job`, `write_job`, …) plus broad `read`/`write`.

## Operations (ALL spec-verified from OpenAPI v2)
- **Pilot (safe, read-only):** `get_current_user` (`/users/current`) — cheapest call; confirms auth + resolves the region base.
- **Candidates:** `find_candidates` (Name/Email/Phone/Location/Keywords/StatusId/…), `get_candidate`, `add_candidate`, `update_candidate`, `set_candidate_status`, `add_candidate_note`, `get_candidate_skills`, `find_candidate_attachments`, list helpers (`get_candidate_statuses`, `get_candidate_custom_fields`).
- **Jobs:** `find_jobs` (Active/CompanyId/StatusId/…), `get_job`, `add_job`, `update_job`, `set_job_status`, `get_job_applications`, `add_candidates_to_job`, `get_job_statuses`.
- **Companies / Contacts:** `find_companies`/`get_company`/`add_company`/`update_company`/`get_company_contacts`; `find_contacts`/`get_contact`/`add_contact`/`update_contact`.
- **Applications / Placements / Ads / Reqs / Opps:** `find_applications`/`get_application`/`update_application`/`set_application_status`/`get_application_statuses`; `find_placements`/`get_placement`; `find_job_ads`/`get_job_ad`; `find_requisitions`/`get_requisition`; `find_opportunities`.
- **Notes / identity search:** `find_notes`, `add_note`, `search_by_email`, `search_by_phone`.

## Gotchas
- **⚠️ `update_*` (PUT) is a FULL-RESOURCE REPLACE, not a patch — READ-MERGE-WRITE.** A `PUT /contacts|companies|candidates/{id}` with only the field you want to change will **blank every field you omit** (e.g. `update_contact(id, {"social": {...}})` wipes name/email/company). Always `get_*` first, merge your change into the existing object, then PUT the full body. Verified live 2026-06-03. Applies to nested objects too: to set `social.linkedin`, copy the existing `social` dict and add the key.
- **⚠️ Custom-field writes fail SILENTLY and need a specific shape.** Payload is `custom:[{"fieldId":N,"value":...}]` — singular **`value`** (not `values`); for a **List** field the value is an **array even for one option** (`"value":["Agency"]`), Text → `"value":"text"`, Date → `"value":"2018-07-01"`. A wrong shape returns **200 with no error but does NOT persist**. **Always read the record back and confirm the `custom` array** rather than trusting the 200. (Standard fields echo correctly, but read-back is still the safe default.) Custom-field IDs are account-specific — fetch `get_*_custom_fields()` first.
- **Count-peek before paging:** every list takes `Limit=0` → returns only `totalCount` (no item bodies). Use `count(path, **filters)`; then `paginate(path, ...)` walks `Offset`/`Limit` (Limit max **1000**, default 100). Lists return `{items, totalCount, links}`.
- **Date filters** (`CreatedAt`/`UpdatedAt`/…) are ISO date-time and accept a `<`/`>` prefix for before/after; pass the same param twice for a range.
- **Duplicate handling:** `add_candidate`/`add_company`/`add_contact` return **409** with an `X-Allow-Duplicates` response header on dup email/name; pass that code back via `allow_duplicates=` to force-create.
- **IDs are int** (candidateId/jobId/companyId int32; applicationId int64). Status/custom-field IDs are account-specific — fetch the `lists/status` + `fields/custom` definitions per account before writing.

## Guardrails
- Production ATS writes — **pilot one record, confirm, then bulk.** Request the **minimum scopes** needed.
- Secrets env-only; never commit the client secret or refresh token.

## Handoff
ATS write target: enriched/qualified candidates → `add_candidate` → `add_candidates_to_job` (attach to the open req). Pairs with the multi-source candidate-search recipe (source → enrich → load into JobAdder).

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute jobadder <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get jobadder <method>` returns the live contract + cost). Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `add_candidate(payload: dict, *, allow_duplicates: str | None = None) -> Any` — POST /candidates — AddCandidateCommand. On 409 (duplicate email) the response header X-Allow-Duplicates carries an override code; pass it back as allow_duplicates to force-create.
- `add_candidate_note(candidate_id: int, text: str, *, type: str | None = None, created_by_integration: bool | None = None) -> Any` — POST /candidates/{id}/notes — text required (<=65535 chars).
- `add_candidates_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /candidates for many records, respecting JOBADDER_RATE_LIMIT_RPM.
- `add_candidates_to_job(job_id: int, candidate_ids: list[int], *, source: str | None = None) -> Any` — POST /jobs/{id}/applications — attach existing candidate(s) to a job (creates applications).
- `add_companies_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /companies for many records, rate-limited.
- `add_company(payload: dict, *, allow_duplicates: str | None = None) -> Any` — POST /companies — AddCompanyCommand (name required); 409 on dup name → X-Allow-Duplicates.
- `add_contact(payload: dict, *, allow_duplicates: str | None = None) -> Any` — POST /contacts — AddContactCommand; 409 on dup email → X-Allow-Duplicates override.
- `add_contacts_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /contacts for many records, rate-limited.
- `add_job(payload: dict) -> Any` — POST /jobs — AddJobOrderCommand (jobTitle required).
- `add_jobs_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /jobs for many records, rate-limited.
- `add_note(payload: dict) -> Any` — POST /notes — AddNoteCommand (type+text required; link via candidateId/jobId/companyId/... arrays).
- `batch(method: str, calls: list, *, stop_on_error: bool = False) -> dict` — Batched get/search/update/create: run one method over many inputs, rate-limited. Each call is a value -> method(value), or {"args": [...], "kwargs": {...}} for multi-arg methods like update_candidate(id, payload). Destructive methods (delete) are refused. See lib/_base.run_ops.
- `count(path: str, **params) -> int` — Cheap count-peek: GET with Limit=0 returns only totalCount (no item bodies / no deep paging).
- `find_applications(**params) -> Any` — GET /applications — ApplicationId, CandidateId, JobId, AdId, StatusId, Active(bool), Rejected(bool), Keywords, CreatedAt/UpdatedAt, Sort, Offset, Limit.
- `find_candidate_attachments(candidate_id: int, **params) -> Any`
- `find_candidates(**params) -> Any` — GET /candidates — filters: Name, Email, Phone, CurrentPosition, City, State, Location, Keywords (resume text), StatusId, RecruiterUserId, CreatedAt/UpdatedAt (prefix `<`/`>`), Sort, Fields (recruiters,statistics), Embed (self,applications,placements,skills,notes), Offset, Limit.
- `find_companies(**params) -> Any` — GET /companies — Name, CompanyId, StatusId, CreatedAt/UpdatedAt, Embed (self,addresses,contacts,subsidiaries,skills,notes,jobs,placements), Offset, Limit.
- `find_contacts(**params) -> Any` — GET /contacts — Name, Email, Phone, CompanyId, HiringManager(bool), StatusId, CreatedAt/UpdatedAt, Embed (self,skills,notes,jobs), Offset, Limit.
- `find_job_ads(**params) -> Any` — GET /jobads — posted job ads (Embed: self,applications).
- `find_jobs(**params) -> Any` — GET /jobs — JobId, JobTitle, CompanyId, ContactId, StatusId, Active(bool), UserId, OwnerUserId, RecruiterUserId, CreatedAt/UpdatedAt, Sort, Fields (recruiters,statistics,partnerActions), Embed (self,notes,applications), Offset, Limit.
- `find_notes(**params) -> Any` — GET /notes — by CandidateId/CompanyId/ContactId/JobId/PlacementId/ApplicationId, EntityType, Type, CreatedAt/UpdatedAt, Fields=text, Offset, Limit.
- `find_opportunities(**params) -> Any` — GET /opportunities — Active(bool), OwnerId, CompanyId, WorkTypeId, EstimatedClose, Offset, Limit.
- `find_placements(**params) -> Any` — GET /placements — PlacementId, Type, StatusId, CandidateId, CompanyId, JobId, StartDate/EndDate, Approved(bool), CreatedAt/UpdatedAt, Offset, Limit.
- `find_requisitions(**params) -> Any` — GET /requisitions — RequisitionId, CompanyId, Status, HiringManager.ContactId, Offset, Limit.
- `find_users(**params) -> Any` — GET /users — UserId/OfficeId/GroupId/Include + Offset/Limit.
- `get_application(application_id: int) -> Any`
- `get_application_statuses(**params) -> Any` — GET /applications/lists/status — application status definitions (workflow stages).
- `get_candidate(candidate_id: int, *, embed: str | None = None) -> Any` — GET /candidates/{id} — Embed: skills,notes,applications,placements.
- `get_candidate_custom_fields() -> Any` — GET /candidates/fields/custom — custom-field definitions (ids for AddCandidate.custom).
- `get_candidate_skills(candidate_id: int) -> Any`
- `get_candidate_statuses(**params) -> Any` — GET /candidates/lists/status — status definitions (ids for set_candidate_status).
- `get_company(company_id: int, *, embed: str | None = None) -> Any`
- `get_company_contacts(company_id: int) -> Any`
- `get_contact(contact_id: int, *, embed: str | None = None) -> Any`
- `get_current_user() -> Any` — GET /users/current — authenticated user; cheapest call to confirm auth + region base.
- `get_job(job_id: int, *, embed: str | None = None) -> Any` — GET /jobs/{id} — Embed: applications,notes.
- `get_job_ad(ad_id: int, *, embed: str | None = None) -> Any`
- `get_job_applications(job_id: int, **params) -> Any` — GET /jobs/{id}/applications — applications attached to a job.
- `get_job_statuses(**params) -> Any` — GET /jobs/lists/status — job status definitions.
- `get_placement(placement_id: int, *, embed: str | None = None) -> Any`
- `get_requisition(requisition_id: int, *, embed: str | None = None) -> Any`
- `paginate(path: str, *, limit: int = 100, max_items: int | None = None, **params) -> list` — Walk Offset/Limit pages, collecting `items`. Caps at max_items if given.
- `search_by_email(email: str) -> Any` — GET /search/emailaddress — resolve candidates/contacts/users by email (identity match).
- `search_by_phone(e164: str) -> Any` — GET /search/phonenumber — resolve candidates/contacts/companies/users by E.164 phone.
- `set_application_status(application_id: int, status_id: int, *, note: dict | None = None) -> Any`
- `set_candidate_status(candidate_id: int, status_id: int, *, note: dict | None = None) -> Any` — PUT /candidates/{id}/status — change status (+optional {type,text} note).
- `set_job_status(job_id: int, status_id: int, *, note: dict | None = None) -> Any`
- `update_application(application_id: int, payload: dict) -> Any` — PUT /applications/{id} — status + custom fields (UpdateJobApplicationCommand).
- `update_candidate(candidate_id: int, payload: dict) -> Any`
- `update_company(company_id: int, payload: dict) -> Any`
- `update_contact(contact_id: int, payload: dict) -> Any`
- `update_job(job_id: int, payload: dict) -> Any`

<!-- API-SURFACE:END -->

## Bulk writes & rate limits

For large pushes use `add_candidates_batch`, `add_companies_batch`, `add_contacts_batch`,
`add_jobs_batch`. They pace calls to a conservative **120 req/min** default and return
`{created, failed, total, elapsed_ms}`. Override with `JOBADDER_RATE_LIMIT_RPM`. See
`crm-bulk-pushes.md` for the cross-CRM guide.
