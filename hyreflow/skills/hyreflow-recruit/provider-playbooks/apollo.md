Use Apollo as a high-recall people/company prospector only when the workspace has an Apollo BYOK key configured.

Apollo access rule:

- Apollo is **BYOK-only** in Hyreflow. If the workspace has no Apollo key configured, Apollo flat tools and the Apollo step inside `people_search` are unavailable/skipped with `no_key`.
- Do not assume a Hyreflow-managed Apollo key exists for user workspaces.
- For normal sourcing, use the `people_search` waterfall first. Drop to `apollo_*` flat tools only when the user intentionally asks for an Apollo-only/provider-native override and Apollo BYOK is configured.

Company vs CRM split:

- `apollo_company_search` maps to Apollo Organization Search (`mixed_companies/search`).
- Use `apollo_company_search` when you want Apollo's broad company database, including companies that are not in your team's CRM yet.
- `apollo_search_accounts` maps to Apollo CRM Account Search (`accounts/search`).
- Use `apollo_search_accounts` only when you specifically want accounts your team already added to Apollo CRM.
- If the task is "find companies," "resolve a company," or "search non-CRM companies," use `apollo_company_search`.
- If the task is "search my Apollo accounts" or depends on CRM stages/ownership/workflow state, use `apollo_search_accounts`.

People search split:

- `apollo_search_people` maps to Apollo `mixed_people/api_search` (preview, no Apollo credits, obfuscated names/contact gaps) — this is the only people-search flat tool the engine currently exposes for Apollo.
- There is no paid/full `mixed_people/search` flat tool on this engine yet (`apollo_people_search_paid` is registered but returns 501 "not available on this engine yet" — do not tell users it works). `apollo_people_search` and `apollo_search_people_with_match` are not registered tool names at all and will 404.
- Use `people_search` first for discovery and shortlist building; switch to `apollo_search_people` only for an Apollo-only/provider-native override after confirming Apollo BYOK is configured.
- `apollo_enrich_person` and `apollo_enrich_organization` are the real Apollo enrichment methods (note: `enrich_organization`, not `enrich_company` — there is no `apollo_enrich_company`/`apollo_reveal_person` tool).
- `q_keywords` is useful for broad text discovery, but it is not the only way to search non-CRM companies or people. If you already know the company, prefer `q_organization_domains_list` or `organization_ids`.

- Keep `include_similar_titles=true` unless the user explicitly asks for strict title matching.
- For broad discovery, start with `person_seniorities` + `q_keywords` and only tighten after you inspect totals.
- Prefer keyword-style constraints in `q_keywords` and `q_organization_name` over overly narrow exact strings.
- Use `apollo_company_search` to resolve account identity first; when running company-targeted `apollo_search_people`, pass `q_organization_domains_list` or `organization_ids` (avoid name-only keyword targeting).
- Use low `per_page` for pilot checks, then scale once payload shape and match quality are confirmed.
- For changed-company email recovery specifically, do not force Apollo first; prefer the scenario default order from the GTM meta skill.

Company-search planning guardrails:

- Start with a pilot query: `per_page=1..3`, plus either `q_organization_name` or exact domains, before broad pagination.
- Treat `organization_num_employees_ranges` as contract-sensitive. Use the exact format shown by `hyreflow tools get apollo_company_search`, and update stale local examples when the live contract changes.
- For exact industry targeting, use `organization_industry_tag_ids` with Apollo taxonomy IDs. `q_organization_keyword_tags` is keyword/description search and can pull off-industry companies that mention the terms.
- Apollo does not publish the industry taxonomy in the Organization Search OpenAPI spec. Discover IDs from `industry_tag_id` / `industry_tag_hash` in organization rows or from Apollo UI/network payloads.
- Inspect `result.data.organizations`; organization rows include Apollo's human-readable `industry` field when Apollo returns it.
- Do not trust `pagination.total_entries` alone when planning a large pull. Verify that retrieved rows, returned shape, and deduped output all look sane on a pilot before fanning out.

Response-shape contract (critical):

- Apollo's native people-search payload shape is top-level: `{ total_entries, people, pagination }`.
- Hyreflow wraps provider payloads in a standard result envelope: `{ data, meta }`.
- Therefore:
  - In `hyreflow tools execute ... `, read people at `result.data.people`.
  - In `hyreflow enrich` row expressions, read people at `<column>.result.data.people`.
  - Do not insert an extra wrapper layer when reading Apollo's native top-level `people` list.

Company search shape gotcha (critical):

- Apollo company search is canonical at `organizations` (not `accounts`).
- In Hyreflow output, prefer `result.data.organizations` (or `<column>.result.data.organizations` in enrich columns).
- Recommended extractor pattern:

```javascript
const q = (row['Company'] || '').trim().toLowerCase();
const d = row['apollo_company']?.result?.data || {};
const orgs = d.organizations || [];
const match =
  orgs.find((x) => (x?.name || '').trim().toLowerCase() === q) ||
  orgs[0] ||
  null;
if (!match) return null;
return {
  company_name: match.name || null,
  company_domain: match.primary_domain || match.domain || null,
  company_linkedin: match.linkedin_url || null,
  company_industry: match.industry || null,
};
```

Quick shape check command:

```bash
hyreflow tools execute apollo_company_search --payload '{"q_organization_name":"Stripe","per_page":3,"page":1}'
```

Obfuscated last-name handling (for email pattern workflows):

- Detect redacted/obfuscated last names early (for example: `S****`, `K.`, `-`, `N/A`, `redacted`, masked punctuation-heavy strings).
- Treat `last_name_obfuscated` from `apollo_search_people` as non-authoritative for name-based email finding.
- Do not pass obfuscated last names into `leadmagic_email_finder` or pattern generators.
- Required bridge step for id-only lookups: `apollo_search_people` -> `bulk_enrich_people` with `details: [{ id }]` -> use the returned full-name fields for name-dependent flows.
- If last name is obfuscated, do not rely on `first.last` / `first.lastInitial` / `firstInitial.lastInitial` patterns as primary candidates.
- Prefer fallback order: direct provider email fields and enrichment lookups first (Apollo/person enrichment/LinkedIn-based enrichment), then emit pattern candidates only when confidence is acceptable.
- Persist deterministic flags for downstream branching, for example `last_name_obfuscated=true` and `name_quality=low|medium|high`.
- Keep recall-first behavior: obfuscation checks should gate pattern generation quality, not force strict matching globally.

```bash
hyreflow tools get apollo_search_people
hyreflow tools get apollo_people_search_paid
```

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute apollo <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get apollo <method>` returns the live contract + cost). Base: `https://api.apollo.io/api/v1`. Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `activate_sequence(sequence_id: str) -> dict` — POST /emailer_campaigns/{id}/approve — starts the sequence sending.
- `add_contacts_to_sequence(sequence_id: str, contact_ids: list[str], email_account_id: str, **opts) -> dict` — POST /emailer_campaigns/{id}/add_contact_ids — ENROLLS contacts into live outreach.
- `bulk_create_contacts(contacts: list[dict], **opts) -> dict` — POST /contacts/bulk_create — create multiple CRM contacts in your Apollo in one call.
- `bulk_enrich_organizations(domains: list[str], **opts) -> dict` — POST /organizations/bulk_enrich — up to 10 domains per call.
- `bulk_enrich_people(details: list[dict], **opts) -> dict` — POST /people/bulk_match — enrich up to 10 people per call. Consumes Apollo credits (BYOK-only: 0 hyreflow credits, charged by Apollo to the customer's own plan).
- `create_account(payload: dict) -> dict` — POST /accounts — create a CRM account (company) in your Apollo.
- `create_contact(payload: dict) -> dict` — POST /contacts — create a CRM contact in your Apollo.
- `deactivate_sequence(sequence_id: str) -> dict` — POST /emailer_campaigns/{id}/abort — stops the sequence sending.
- `enrich_organization(domain: str, **params) -> dict` — GET /organizations/enrich — enrich one company by domain.
- `enrich_person(payload: dict) -> dict` — POST /people/match — enrich one person (email/phone). Consumes Apollo credits (BYOK-only: 0 hyreflow credits, billed by Apollo to the customer's own plan — still gated spend).
- `get_organization(org_id: str) -> dict`
- `list_email_accounts(**params) -> Any` — GET /email_accounts — sending mailboxes (need an id to enroll into sequences).
- `list_fields(**params) -> Any`
- `list_lists(**params) -> Any` — GET /labels — Apollo lists.
- `list_users(**params) -> Any`
- `organization_job_postings(org_id: str, **params) -> Any`
- `search_accounts(filters: dict | None = None) -> Iterator[dict]`
- `search_contacts(filters: dict | None = None) -> Iterator[dict]` — POST /contacts/search — search your Apollo contacts.
- `search_organizations(filters: dict | None = None) -> Iterator[dict]` — POST /mixed_companies/search — company/account search.
- `search_people(filters: dict | None = None) -> Iterator[dict]` — POST /mixed_people/api_search — prospect net-new people. No emails/phones, no credits.
- `search_sequences(filters: dict | None = None) -> Iterator[dict]` — POST /emailer_campaigns/search.
- `update_account(account_id: str, payload: dict) -> dict` — PATCH /accounts/{account_id} — update a CRM account.
- `update_contact(contact_id: str, payload: dict) -> dict` — PATCH /contacts/{contact_id}.
- `view_account(account_id: str) -> dict`
- `view_contact(contact_id: str) -> dict`

<!-- API-SURFACE:END -->
