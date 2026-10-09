---
name: carerix
description: "Read/write Carerix (recruiting ATS/CRM) via its GraphQL API — list/get candidates, vacancies, companies, contacts, matches and notes, create candidates (with duplicate detection) and notes, and update a match's pipeline status. Use when the user mentions Carerix, pushing candidates into the ATS, or reading vacancies/contacts/companies. Keys: BYOK-only — the workspace connects its own Carerix client (Client ID + Client Secret + Carerix URL)."
---

# Carerix — Integration Meta Skill

HOW in `lib/carerix.py`. Docs: docs.carerix.io/graphql.

## Auth & config (client credentials)
- **Connect (BYOK):** dashboard **Integrations → Carerix** — the **Client ID** and **Client Secret** of a *confidential* client (in Carerix: **Identity Access → Clients**, with the data scope enabled), plus your **Carerix URL** (the login address, e.g. `https://acme.carerix.net`; the bare tenant name `acme` works too). Tenants on a non-default Carerix identity host are not supported yet. CLI: `hyreflow byok set carerix --api-key <client_id> --field client_secret=<secret> --field tenant=<carerix url or tenant name>`.
- Hyreflow fetches and refreshes the access token for you; only the tenant name is read from the Carerix URL (it picks the login realm); the pasted URL itself is never fetched.
- Every call is one GraphQL request to Carerix's single endpoint. Limit: 10 requests/second (600/min), paced for you. Each `list_*` call returns one page (`page` from 0, `page_size` at most 100 — a larger value is rejected, not trimmed).

## Operations
Read: `ping`, `list_candidates` / `search_candidates` / `get_candidate`, `list_vacancies` / `get_vacancy`, `list_companies` / `get_company`, `list_contacts` / `get_contact`, `list_matches` / `get_match`, `list_notes` / `get_note`. Write: `create_candidate` (duplicate detection on by default), `create_note`, `update_match`. Bulk: `create_candidates_batch`, plus the generic `batch` for get/search/update/create calls (see `crm-bulk-pushes.md`), e.g. `batch("search_candidates", [qualifier, ...])` for a bulk lookup (one page per qualifier).

## Notes & guardrail
- **Vocabulary:** Carerix calls a candidate an *employee*, a client contact a *user*, a candidate-to-vacancy link a *match* (it carries the pipeline status) and a note a *to-do of kind note*. The methods here use the recruiter names.
- **Filtering:** `list_*` take a `qualifier` (Carerix's filter string, for example `toDoTypeKey=0`); `search_candidates` requires one, e.g. `emailAddress = 'jane@acme.example'`. The qualifier goes to Carerix as written, so single-quote string values and escape any quote inside them. Results come back oldest-created first (candidates, vacancies, companies and contacts break ties on their own id), one page per call: raise `page` until a page comes back short.
- **`create_candidate`** takes the candidate fields as Carerix names them — `firstName`, `lastName`, `emailAddress`, `mobileNumber`, `phoneNumber`, `city`, `title`, `notes` — and needs at least `lastName` or `emailAddress`. `dedupe` is on, which asks Carerix to detect duplicates, but the match key depends on the tenant's setup: `search_candidates` by email first, and pilot one record before a bulk push.
- **`create_note`** needs the tenant's note type (`toDoTypeKey`, from Carerix's TodoTypeKey list: read it off an existing note with `get_note` if unsure) and a link to what the note is about: `{"subject": "Intro call", "toDoTypeKey": <note type>, "toNotes": {"_kind": "CRToDoNotes", "notes": "Spoke on Monday"}, "toEmployee": {"_kind": "CREmployee", "_id": "123"}}`. Use `toVacancy`, `toMatch`, `toCompany` or `toContact` for the other record types.
- **`update_match`** changes a match, e.g. `{"notes": "Shortlisted"}`, or moves its pipeline status with `{"statusInfo": {"_kind": "CRStatusInfo", "_id": "<status id>"}}`. Status ids are specific to the tenant, so read one off an existing match (`get_match`) first.
- **Writes are not retried after a timeout or server error.** Those may still have applied the create or update, so check (`search_candidates`, `get_match`) before you resend. The only re-sends are after a rate-limit (429) or an authentication refusal (HTTP 401, or GraphQL `UNAUTHENTICATED` on the top-level field), which Carerix rejects before they run.
- There is no record delete.
- Production ATS writes — pilot one record, confirm, then bulk.

## Handoff
ATS write target: enriched candidates → `create_candidate` (or `create_candidates_batch`); reply or call notes → `create_note`; pipeline moves → `update_match`.
Company-first BD: `list_companies` → each company's `url` → `hyreflow_native` career-page scraping for their open roles → contacts via the `people_search` waterfall.

## Bulk writes & rate limits

For large pushes use `create_candidates_batch`. It paces calls to the **600 req/min** default and returns
`{created, failed, total, elapsed_ms}`. See `crm-bulk-pushes.md` for the cross-CRM guide.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute carerix <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get carerix <method>` returns the live contract + cost). Base: `https://api.carerix.io/graphql/v1/graphql`. Only the methods listed below are callable.

- `batch(method: str, calls: list, *, stop_on_error: bool = False) -> dict` — Batched get/update/create: run one method over many inputs, rate-limited.
- `create_candidate(payload: dict, *, dedupe: bool = True) -> dict` — POST /graphql/v1/graphql — crEmployeeCreate: create a candidate (CREmployeeRequest, e.g. {"firstName", "lastName", "emailAddress"}).
- `create_candidates_batch(payloads: list[dict], *, stop_on_error: bool = False) -> dict` — POST /graphql/v1/graphql — crEmployeeCreate: create many candidates sequentially and rate-limited, each with Carerix's duplicate detection on (its match key is tenant-specific: search first).
- `create_note(payload: dict) -> dict` — POST /graphql/v1/graphql — crToDoCreate: add a note to a candidate, vacancy, match, company or contact.
- `get_candidate(candidate_id: str) -> dict` — POST /graphql/v1/graphql — crEmployee: one candidate by id.
- `get_company(company_id: str) -> dict` — POST /graphql/v1/graphql — crCompany: one company by id.
- `get_contact(contact_id: str) -> dict` — POST /graphql/v1/graphql — crContact: one contact by id.
- `get_match(match_id: str) -> dict` — POST /graphql/v1/graphql — crMatch: one match by id.
- `get_note(note_id: str) -> dict` — POST /graphql/v1/graphql — crNote: one note by id.
- `get_vacancy(vacancy_id: str) -> dict` — POST /graphql/v1/graphql — crVacancy: one vacancy by id.
- `list_candidates(qualifier: str | None = None, page: int = 0, page_size: int = 100) -> list[dict]` — POST /graphql/v1/graphql — crEmployeePage: one page of candidates (CREmployee), oldest first. `qualifier` is Carerix's filter string.
- `list_companies(qualifier: str | None = None, page: int = 0, page_size: int = 100) -> list[dict]` — POST /graphql/v1/graphql — crCompanyPage: one page of client companies (CRCompany), oldest first.
- `list_contacts(qualifier: str | None = None, page: int = 0, page_size: int = 100) -> list[dict]` — POST /graphql/v1/graphql — crContactPage: one page of client contacts (CRUser), oldest first.
- `list_matches(qualifier: str | None = None, page: int = 0, page_size: int = 100) -> list[dict]` — POST /graphql/v1/graphql — crMatchPage: one page of matches (CRMatch), the candidate-to-vacancy links that carry the pipeline status.
- `list_notes(qualifier: str | None = None, page: int = 0, page_size: int = 100) -> list[dict]` — POST /graphql/v1/graphql — crNotePage: one page of notes (a note is a CRToDo), oldest first.
- `list_vacancies(qualifier: str | None = None, page: int = 0, page_size: int = 100) -> list[dict]` — POST /graphql/v1/graphql — crVacancyPage: one page of vacancies (CRVacancy), oldest first.
- `ping() -> dict` — POST /graphql/v1/graphql — crEmployeePage: free read, one row count. Verifies the credentials, tenant and candidate read access (the BYOK probe).
- `search_candidates(qualifier: str, page: int = 0, page_size: int = 100) -> list[dict]` — POST /graphql/v1/graphql — crEmployeePage: one page of candidates matching a required qualifier, e.g. `emailAddress = 'jane@acme.example'`.
- `update_match(match_id: str, payload: dict) -> dict` — POST /graphql/v1/graphql — crMatchUpdate: update a match's notes or move its pipeline status.

<!-- API-SURFACE:END -->
