# Bulk pushes to ATS / recruiting CRMs

Use this playbook when the user wants to write many candidates, contacts, companies or jobs into any
Hyreflow-supported recruiting CRM/ATS.

## Operational defaults

All CRM adapters pace writes with a token-scoped rate limiter. Defaults:

- Bullhorn: 1,500 req/min (per OAuth Client ID). `BULLHORN_RATE_LIMIT_RPM` to override.
- JobAdder: 120 req/min (2/sec, conservative). `JOBADDER_RATE_LIMIT_RPM` to override.
- Loxo: 60 req/min. `LOXO_RATE_LIMIT_RPM` to override.
- Recruiterflow: 60 req/min. `RECRUITERFLOW_RATE_LIMIT_RPM` to override.
- Vincere: 60 req/min. `VINCERE_RATE_LIMIT_RPM` to override.
- Atlas: 60 req/min. `ATLAS_RATE_LIMIT_RPM` to override.
- Recruit CRM: 60 req/min. `RECRUITCRM_RATE_LIMIT_RPM` to override (10 req/min per license for >6 licenses).
- Spott: 600 req/min (per API key). `SPOTT_RATE_LIMIT_RPM` to override.

## Which batch helper to call

| CRM | Candidate / Person | Contact | Company / Client | Job |
|---|---|---|---|---|
| Bullhorn | `create_candidates_batch` | `create_client_contacts_batch` | `create_client_corporations_batch` | `create_job_orders_batch` |
| JobAdder | `add_candidates_batch` | `add_contacts_batch` | `add_companies_batch` | `add_jobs_batch` |
| Loxo | `create_people_batch` | — | `create_companies_batch` | `create_jobs_batch` |
| Recruiterflow | `add_candidates_batch` | `add_contacts_batch` | `add_clients_batch` | `create_jobs_batch` |
| Vincere | `create_candidates_batch` | — | — | — |
| Atlas | `create_people_batch` | — | `create_companies_batch` | `create_projects_batch` / `create_opportunities_batch` |
| Recruit CRM | `create_candidates_batch` | `create_contacts_batch` | `create_companies_batch` | — |
| Spott | `create_candidates_batch` | — | `create_clients_batch` | — |

## Bulk helper contract

- Signature: `<batch_name>(payloads: list[dict], *, stop_on_error: bool = False) -> dict`
- Return: `{created: [...], failed: [{payload, error, status}], total, elapsed_ms}`
- Errors on individual rows are collected in `failed`; the loop continues unless `stop_on_error=True`.
- Batch helpers call the existing single-record create methods, so any field/payload validation still applies.

## Batched get / search / update — the generic `batch` method

The typed `create_*_batch` helpers are insert-only. Every CRM also exposes `batch(method, calls, *,
stop_on_error=False)` to fan **any** read/update method across many inputs with the same pacing:

- Each entry in `calls` is a plain value → `method(value)` (an id, a query string), or
  `{"args": [...], "kwargs": {...}}` → `method(*args, **kwargs)` (multi-arg methods like
  `update_candidate(slug, payload)` or bullhorn's `update_entity(entity, id, payload)`).
- Return: `{results: [...], failed: [{call, error, status}], total, elapsed_ms}`.
- **Deletes are refused** — `batch` blocks destructive verbs and the adapters expose no record-delete op.

Examples: bulk update = `batch("update_candidate", [{"args":[slug, payload]}, ...])`; bulk fetch =
`batch("get_candidate", [slug1, slug2])`; bulk lookup = `batch("search_by_email", [e1, e2])`.

## Cost gate

ATS/CRM writes are free. Before running a large enrichment, call `/enrich/run` with `estimate=True` or use
`hyreflow enrich --estimate` to get a worst-case credit cost. The run is only blocked if the balance can't
cover even one row at the worst-case rate; if the balance covers a row but not the full estimate, the run
proceeds and the response carries a `partial_budget` warning that later rows may come back without a
result. When it's blocked, the engine returns a Stripe checkout link; do not proceed until the user adds
credits.

## Procedure for 1,000+ records

1. Confirm the user's CRM credentials are stored (`byok` or workspace provider config).
2. Estimate the run cost: `hyreflow enrich --estimate --file <csv> --with <tool> --with <crm>.<batch>`.
3. If balance can't cover even one row at the worst-case rate, stop and ask the user to top up credits.
   Otherwise proceed — watch for a `partial_budget` warning if the balance may not cover every row.
4. Pilot one payload manually through the single-record method.
5. Build the list of payloads and call the batch helper with `stop_on_error=False`.
6. Report `{created_count, failed_count, total, elapsed_ms}` and surface the first few failed rows.

## References

- `apps/web/content/docs/integrations/crm-bulk-pushes.mdx` — user-facing version
